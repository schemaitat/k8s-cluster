#!/bin/bash
set -e 

config=$1

# unique label for the cluster
CLUSTER=$(cat $config | yq '.cluster')
CMD=""
for pool in $(cat $config | yq e -o=j -I=0 '.nodePools[]'); do
    type=$(echo $pool | jq '.type' | sed 's|"||g')
    count=$(echo $pool | jq '.count')
    CMD="${CMD} --node_pools.type $type --node_pools.count $count"
    HOURLY_COST=$(linode-cli linodes type-view $type --text --no-headers | awk '{print $10}')
    TOTAL_HOURLY_COST=$(python3 -c "x=$HOURLY_COST; y=$count; print(x*y);")
    echo "Found nodepool with type $type and count $count."
    echo "Total hourly cost for the nodepool: $TOTAL_HOURLY_COST\$."
done


CLUSTER_ID=$(linode-cli lke clusters-list --json | jq '.[] | select(.label=="'$CLUSTER'") | .id')
if [ ${#CLUSTER_ID} -ne 0 ]; then
    echo "Cluster with label $CLUSTER already exists."
else
    linode-cli lke cluster-create --label $CLUSTER  \
        --region eu-central \
        --k8s_version 1.24 \
        $CMD \
        --tags dev 2>&1 >/dev/null
    CLUSTER_ID=$(linode-cli lke clusters-list --json | jq '.[] | select(.label=="'$CLUSTER'") | .id')
    echo "Cluster with id $CLUSTER_ID has been created."
fi

linode-cli lke clusters-list --label $CLUSTER
set +e 

IS_READY=false
while [ "$IS_READY" == "false" ]; do
    linode-cli lke pools-list $CLUSTER_ID --text --format status --no-headers 2>&1 | grep "not_ready" 2>&1 >/dev/null
    RC=$?
    if [[ ! $RC -eq 0 ]]; then
        IS_READY=true
        continue
    fi
    sleep 5
    echo "Waiting for cluster to be ready ..."
done


echo "Cluster is ready."

set -e

export KUBECONFIG=~/${CLUSTER}-kubeconfig.yaml
linode-cli lke pools-list $CLUSTER_ID
echo "Copying kubeconfig to $KUBECONFIG."
linode-cli lke kubeconfig-view $CLUSTER_ID --json --no-headers | jq '.[].kubeconfig' | sed 's|"||g' | base64 -D > $KUBECONFIG
chmod 700 $KUBECONFIG

# control output
echo "Running pods:"
kubectl get pods -A


echo "Installing Argo CD:"
# install argocd  and set up namespaces
helm dep update charts/argo-cd
helm dep update airflow

namespaces="argocd monitoring airflow"
for ns in $namespaces; do
    kubectl create ns $ns
done

helm install argo-cd charts/argo-cd/ -n argocd

#wait for argo cd to be deployed
argo_deployments=$(kubectl get deployments -n argocd --no-headers=true | awk '{print $1}')
for dep in $argo_deployments; do
    echo "Waiting for deployment $dep to be available..."
    kubectl wait deployment -n argocd $dep --for condition=Available=True --timeout=300s
done

echo "Installing root application:"
# install root application
kubectl apply -f apps/templates/root.yaml