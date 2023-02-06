#!/bin/bash

CLUSTER_NAME=$1;
REGISTRY_NAME=$2;
REGISTRY_PORT=$3;
NB_NODES=$4

namespaces=(ingress-nginx api)


if k3d cluster list $CLUSTER_NAME 2>&1 > /dev/null; then
    docker start k3d-$REGISTRY_NAME
    k3d cluster start $CLUSTER_NAME;
    kubectl config use-context k3d-$CLUSTER_NAME;
else
    echo "INFO: Create cluster..."
    k3d registry create -p 0.0.0.0:$REGISTRY_PORT $REGISTRY_NAME --no-help;
    k3d cluster create $CLUSTER_NAME \
        -a $NB_NODES \
        -p '80:80@loadbalancer' \
        -p '443:443@loadbalancer' \
        -p '4200:4200@loadbalancer' \
        --k3s-arg '--disable=traefik@server:0' \
        --registry-use k3d-$REGISTRY_NAME:$REGISTRY_PORT;
    
    kubectl taint node k3d-$CLUSTER_NAME-server-0 node-role.kubernetes.io/master:NoSchedule
    
    kubectl config use-context k3d-$CLUSTER_NAME;

    echo "INFO: Create namespaces..."
    for namespace in ${namespaces[*]}
    do
        kubectl create ns $namespace;
    done

    kubectl apply -f k8s/nginx/nginx.yaml;
fi

kubectl rollout status -n kube-system deployment coredns;
kubectl rollout restart -n kube-system deployment coredns;
