#!/bin/bash

set -e 

export LOG_DEBUG_ENABLE=true

source bin/common.sh

if [ $# -ne 1 ]; then
    log_error "The script expects exatcly 1 argument".
    log_error "Please supply the path to a valid cluster configuration file."
    exit 1
fi

function delete_volume {
    volume=$1
    set +e
    log_info "Deleting volume $volume."
    while true; do
        linode-cli volumes rm $volume
        if [ $? -ne 0 ]; then
            sleep 5
        else
            log_info "Successfully deleted volume $volume."
            break
        fi
        log_info "Waiting for volume $volume to be deattached."
    done
    set -e
}

CLUSTER_CONFIG_FILE=$1

# unique label for the cluster
CLUSTER=$(cat $CLUSTER_CONFIG_FILE | yq '.cluster')
CLUSTER_ID=$(linode-cli lke clusters-list --json | jq '.[] | select(.label=="'$CLUSTER'") | .id')

if [ ${#CLUSTER_ID} -eq 0 ]; then 
    log_info "No cluster with label $CLUSTER found."
    exit 0
fi 

log_info "Found cluster with cluster id $CLUSTER_ID"

log_info "Found the following node pools:"
linode-cli lke pools-list $CLUSTER_ID

LINODES=$(linode-cli lke pools-list $CLUSTER_ID --text --format instance_id --no-headers)

log_notice "Deleting cluster $CLUSTER"
linode-cli lke cluster-delete $CLUSTER_ID
if [ $? -eq 0 ]; then
    echo "Succesfully deleted cluster $CLUSTER."
fi

log_notice "Deleting remaining volumes node-wise."
for node_id in $LINODES; do
    volumes=$(linode-cli volumes ls --json | jq '.[] | select(.linode_id=='$node_id') | .id')
    log_info "The following volumes are attached to node $node_id:"
    echo $volumes

    for volume in $volumes; do
        # waiting for volume to be unattahed
        delete_volume $volume
    done
done

log_info "Remaining overall volumes:"
linode-cli volumes ls