#!/bin/bash
# Use this to delete unattached volumes
# which may be left over for some reason

set -e 

export LOG_DEBUG_ENABLE=true

source bin/common.sh

function wait_for_unattached {
    volume=$1
    while true; do
        attached_to=$(linode-cli volumes view $volume --json | jq '.[] | .linode_id')
        if [ "$attached_to" == "null" ]; then
            linode-cli volumes detach $volume
            sleep 5
            break
        fi
        log_info "Waiting for volume $volume to be deattached from node $node_id."
        sleep 5
    done
}

log_info "Remaining overall volumes:"
linode-cli volumes ls

log_notice "Deleting unattached volumes" 
volumes=$(linode-cli volumes ls --json | jq '.[] | select(.linode_id==null) | .id')
for volume in $volumes; do
    wait_for_unattached $volume
    log_info "Deleting volume $volume."
    linode-cli volumes rm $volume
done

log_info "Remaining overall volumes:"
linode-cli volumes ls