#!/bin/bash

# Get all namespaces and filter the terminating ones
terminating_namespaces=$(kubectl get namespaces --output=json | jq -r '.items[] | select(.status.phase=="Terminating") | .metadata.name')
namespace_prefix="session"
wait_time=3

if [ -z "${terminating_namespaces[@]}" ]; then
    echo "No terminating namespaces detected" 
    exit 0
else 
    echo "Terminating namespaces detected: " 
    for namespace in $terminating_namespaces; do
        echo $namespace
    done 
fi

# Loop through the terminating namespaces
for namespace in $terminating_namespaces; do
    if [[ $namespace == $namespace_prefix* ]]; then
        echo "Beginning cleanup for $namespace" 
        flink_deployments=$(kubectl -n $namespace get flinkdeployments.flink.apache.org -o json | jq -r '.items[] | .metadata.name')
        for deployment in $flink_deployments; do
            echo "patching the finalizer for cr flinkdeployments.flink.apache.org $deployment"
            kubectl -n $namespace patch flinkdeployments.flink.apache.org/$deployment -p '{"metadata":{"finalizers":[]}}' --type=merge
        done
    fi 
done

echo "Deployments patched. Waiting $wait_time seconds to confirm that the namespaces are terminated."
sleep $wait_time

still_terminating_namespaces=$(kubectl get namespaces --output=json | jq -r '.items[] | select(.status.phase=="Terminating") | .metadata.name')
if [ -z "${still_terminating_namespaces[@]}" ]; then
    echo "All terminating namespace have been terminated." 
    exit 0
else 
    echo "The following namespaces failed to terminate." 
    for namespace in $still_terminating_namespaces; do
        echo $namespace
    done 
fi
