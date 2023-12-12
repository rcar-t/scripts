#!/bin/bash 

namespace_regex="^session-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
namespace_prefix="session"
wait_time=10
aging_time=30

date=$(date -u -v-"$aging_time"d '+%Y-%m-%dT%H:%M:%SZ')

function remove_flink_deployments {
    local namespace="$1"
    echo "Beginning cleanup for $namespace" 
    flink_deployments=$(kubectl -n $namespace get flinkdeployments.flink.apache.org -o json | jq -r '.items[] | .metadata.name')
    for deployment in $flink_deployments; do
        echo "patching the finalizer for cr flinkdeployments.flink.apache.org $deployment"
        kubectl -n $namespace patch flinkdeployments.flink.apache.org/$deployment -p '{"metadata":{"finalizers":[]}}' --type=merge
    done
    echo ""
}

function remove_aging_namespaces {
    old_namespaces=$(kubectl get namespaces --output=json | jq -r --arg date "$date" '.items[] | select(.metadata.creationTimestamp < $date) | .metadata.name')

    for namespace in $old_namespaces; do 
        if [[ $namespace =~ $namespace_regex ]]; then 
            echo "deleting namespace $namespace"
            kubectl delete namespace $namespace
        fi
    done
}

function remove_terminating_namespaces {
    # Get all namespaces and filter the terminating ones
    terminating_namespaces=$(kubectl get namespaces --output=json | jq -r '.items[] | select(.status.phase=="Terminating") | .metadata.name')
    

    if [ -z "${terminating_namespaces[@]}" ]; then
        echo "No terminating namespaces detected" 
        return 1
    else 
        echo "Terminating namespaces detected: " 
        for namespace in $terminating_namespaces; do
            echo $namespace
        done
        echo "" 
    fi

    # Loop through the terminating namespaces
    for namespace in $terminating_namespaces; do
        if [[ $namespace == $namespace_prefix* ]]; then
            remove_flink_deployments $namespace
        fi 
    done

    echo "Deployments patched. Waiting $wait_time seconds to confirm that the namespaces are terminated."
    sleep $wait_time

    still_terminating_namespaces=$(kubectl get namespaces --output=json | jq -r '.items[] | select(.status.phase=="Terminating") | .metadata.name')
    if [ -z "${still_terminating_namespaces[@]}" ]; then
        echo "All terminating namespace have been terminated." 
        return 0
    else 
        echo "The following namespaces failed to terminate." 
        for namespace in $still_terminating_namespaces; do
            echo $namespace
        done 
    fi
}

# remove_aging_namespaces
remove_terminating_namespaces