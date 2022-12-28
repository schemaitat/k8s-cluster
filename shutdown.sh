#!/bin/bash

CLUSTER=k8s-dev
CLUSTER_ID=$(linode-cli lke clusters-list --json | jq '.[] | select(.label=="'$CLUSTER'") | .id')
if [ ${#CLUSTER_ID} -eq 0 ]; then 
    echo "No cluster with label $CLUSTER found."
    exit 0
fi 

echo "CLUSTER_ID: $CLUSTER_ID"
LINODES=$(linode-cli lke pools-list $CLUSTER_ID --text --format instance_id --no-headers)

linode-cli lke cluster-delete $CLUSTER_ID
if [ $? -eq 0 ]; then
    echo "Succesfully shut down cluster $CLUSTER."
fi
linode-cli lke clusters-list

# deleting volumes
echo "Deleting remaining volumes."
for node_id in $LINODES; do
    volumes=$(linode-cli volumes ls --json | jq '.[] | select(.linode_id=='$node_id') | .id')
    for volume in $volumes; do
        echo "Deleting volume $volume which has been attached to node $node_id."
        linode-cli volumes delete $volume
    done
done