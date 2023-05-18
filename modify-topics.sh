#!/bin/bash

NAMESPACE=session-2f112df2-6d7d-4a12-8ebd-322cadb9b88a
CONFIG="retention.ms=10800000"
topics=$(kubectl get kafkatopics -o json | jq -r '.items[] | .metadata.name')

for topic in $topics; do 
    if [[ $topic == "pub-"* || $topic == "public."* ]]; then 
        echo "patching $topic"
        echo "kubectl patch kafkatopic "$topic" -n "$NAMESPACE" --type merge -p "{\"spec\":{\"config\":{\"$CONFIG\"}}}""
    fi
done