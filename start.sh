#!/bin/bash
set -e 

export LOG_DEBUG_ENABLE=true

source bin/common.sh

if [ $# -ne 1 ]; then
    log_error "The script expects exatcly 1 argument".
    log_error "Please supply the path to a valid cluster configuration file."
    exit 1
fi

CLUSTER_CONFIG_FILE=$1


function create_cluster {
    # unique label for the cluster
    CREATE_CLUSTER_CMD=""
    CLUSTER=$(cat $CLUSTER_CONFIG_FILE | yq '.cluster')
    REGION=$(cat $CLUSTER_CONFIG_FILE | yq '.region')
    KUBERNETES_VERSION=$(cat $CLUSTER_CONFIG_FILE | yq '.kubernetes-version')

    for pool in $(cat $CLUSTER_CONFIG_FILE | yq e -o=j -I=0 '.nodePools[]'); do
        type=$(echo $pool | jq '.type' | sed 's|"||g')
        count=$(echo $pool | jq '.count')

        CREATE_CLUSTER_CMD="${CREATE_CLUSTER_CMD} --node_pools.type $type --node_pools.count $count"

        HOURLY_COST=$(linode-cli linodes type-view $type --text --no-headers | awk '{print $10}')
        TOTAL_HOURLY_COST=$(python3 -c "x=$HOURLY_COST; y=$count; print(x*y);")

        log_info "Cluster configuration contains nodepool with type $type and count $count."
        log_info "Total hourly cost for this nodepool is $TOTAL_HOURLY_COST\$."
    done

    # check if cluster already exists 
    CLUSTER_ID=$(linode-cli lke clusters-list --json | jq '.[] | select(.label=="'$CLUSTER'") | .id')

    if [ ${#CLUSTER_ID} -ne 0 ]; then
        log_info "Cluster with label $CLUSTER already exists."
        log_info "Skipping the cluster-create step."
    else
        linode-cli lke cluster-create \
            --label $CLUSTER  \
            --region $REGION \
            --k8s_version $KUBERNETES_VERSION \
            $CREATE_CLUSTER_CMD \
            --tags dev 2>&1 >/dev/null
        CLUSTER_ID=$(linode-cli lke clusters-list --json | jq '.[] | select(.label=="'$CLUSTER'") | .id')
        log_info "Cluster with id $CLUSTER_ID has been created."
    fi
}

function wait_for_cluster {
    set +e 
    while true; do
        # status is either ready or not_ready
        linode-cli lke pools-list $CLUSTER_ID --text --format status --no-headers 2>&1 | grep "not_ready" 2>&1 >/dev/null
        RC=$?
        if [ ! $RC -eq 0 ]; then
            break
        fi
        sleep 10
        log_verbose "Waiting for cluster to be ready ..."
    done
    set -e

    log_info "Cluster is ready."
}

function wait_for_kubeapi {
    APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

    set +e
    while true; do
        status=$(curl -sk -o /dev/null -w "%{http_code}" ${APISERVER}/readyz)
        if [ $status -eq 200 ]; then
            break
        fi
        log_info "Waiting for kubernetes api to be ready ..."
        sleep 2
    done
    set -e
}

log_notice "(I) Create cluster"
create_cluster

log_notice "(II) Waiting for cluster to be ready"
wait_for_cluster

export KUBECONFIG=~/${CLUSTER}-kubeconfig.yaml
log_notice "(III) Copying kubeconfig to $KUBECONFIG."
linode-cli lke kubeconfig-view $CLUSTER_ID --json --no-headers | jq '.[].kubeconfig' | sed 's|"||g' | base64 -D > $KUBECONFIG
chmod 700 $KUBECONFIG

log_notice "(IV) Wait for kubeapi to be ready"
wait_for_kubeapi

# control output
log_info "Running pods:"
kubectl get pods -A

log_notice "(V) Creating namespaces"
namespaces="argocd monitoring airflow"
for ns in $namespaces; do
    kubectl create ns $ns
done

log_notice "(VI) Installing Argo CD"
# install argocd  and set up namespaces
helm dep update charts/argo-cd
helm install argo-cd charts/argo-cd/ -n argocd


log_notice "(VII) Waiting for all Argo CD deployments to be available"
#wait for argo cd to be deployed
argo_deployments=$(kubectl get deployments -n argocd --no-headers=true | awk '{print $1}')
for dep in $argo_deployments; do
    log_info "Waiting for deployment $dep to be available ..."
    kubectl wait deployment -n argocd $dep --for condition=Available=True --timeout=300s
done

log_notice "(VIII) Installing root application (app of apps)"
# install root application
kubectl apply -f apps/templates/root.yaml