#!/usr/bin/env bash

set -ex

status=$(minikube status | grep host | awk -F ':' '{print $2}' | tr -d '[:space:]')
spark_data_hostpath=/tmp/spark-data/

if [ -z "$status" ] || [ "$status" -eq "Stopped" ]; then
    echo "Start minikute with 4 cores, 8Gi memory, 30Gi storage"
    minikube start --memory=8192 --cpus=4 --vm-driver=kvm2 --kubernetes-version=v1.14.1 --disk-size=30g
fi

if ! type helm &> /dev/null ; then
    curl https://storage.googleapis.com/kubernetes-helm/helm-v2.13.1-linux-amd64.tar.gz -o /tmp/helm-v2.13.1-linux-amd64.tar.gz
    tar xvzf /tmp/helm-v2.13.1-linux-amd64.tar.gz -C /tmp/
    /tmp/linux-amd64/helm init
    /tmp/linux-amd64/helm install $(dirname "$0")/../charts/spark-cluster
else
    helm init
    if [ ! -d "$spark_data_hostpath" ]; then
        mkdir $spark_data_hostpath
    fi
    if helm ls | grep spark-cluster 2>&1 ; then
        echo "Deployment is found."
    else
        helm install $(dirname "$0")/../charts/spark-cluster -n spark-cluster --set storage.provider=hostpath --set storage.hostPath=$spark_data_hostpath
    fi
fi

echo "Starting a Pyspark shell with spark-submit options: $@"
SPARK_MASTER=$(kubectl get pods | grep spark-master-controller-* | awk '{print $1}')
#master_pod=$(kubectl get pods --show-labels | grep $SPARK_MASTER | awk '{ print $1}')
[[ -z "$SPARK_MASTER" ]] && { echo "no pod found "; exit 1; }

pod_status=`kubectl get pods | grep -i $SPARK_MASTER | awk '{ print $3}'`
while [ "$pod_status" != "Running" ]; do
    echo "Waiting for master to start..."
    sleep 10
    pod_status=`kubectl get pods | grep -i $SPARK_MASTER | awk '{ print $3}'`
done
kubectl exec -it $SPARK_MASTER -- pyspark "$@"
