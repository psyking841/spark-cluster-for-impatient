#!/usr/bin/env bash

usage()
{
    echo "usage: interactive [[[-z | --zone zone ] [-m | --machine machine-type]] [-w | --workers worker-number]] [-n | --name cluster-name]] | [-h | --help]]"
}

ZONE=${ZONE:-dal13}
MACHINE=${MACHINE:-b2c.4x16}
WORKERS=${WORKERS:-3}
CLUSTER_NAME=${CLUSTER_NAME:-mycluster}
DEPLOY_NAME=${DEPLOY_NAME:-spark-cluster-dev}
NAMESPACE=${NAMESPACE:-default}
DRIVER_CORES=1
DRIVER_MEMORY=2G
NUM_EXECUTORS=2
TOTAL_EXECUTOR_CORES=2
EXECUTOR_MEMORY=2G

if [ -f ~/.out ] ; then
    . ~/.out
else
    touch ~/.out
fi

while [[ "$1" != "" ]]; do
    case "$1" in
        -z | --zone )        shift
                             ZONE="$1"
                             ;;
        -m | --machine  )    shift
                             MACHINE="$1"
                             ;;
        -w | --workers  )    shift
                             WORKERS="$1"
                             ;;
        -n | --cluster-name  )       shift
                             CLUSTER_NAME="$1"
                             ;;
        -h | --help )        usage
                             exit
                             ;;
        *  )                 usage
                             exit 1
    esac
    shift
done

echo "Checking to see if the cluster '${CLUSTER_NAME}' already exists..."
if ibmcloud ks clusters | grep "^${CLUSTER_NAME} .* normal " > /dev/null 2>&1 ; then
    echo "Cluster already exists"
else
    echo "Creating ${CLUSTER_NAME}"

    echo Get our VLAN info
    ibmcloud ks vlans --zone $ZONE
    PRI_VLAN=$(grep private out | sed "s/ .*//")
    PUB_VLAN=$(grep public out | sed "s/ .*//")

    echo "Create the cluster"
    ibmcloud ks cluster-create --name ${CLUSTER_NAME} --zone ${ZONE} \
        --machine-type ${MACHINE} \
        --workers ${WORKERS} --private-vlan ${PRI_VLAN} \
        --public-vlan ${PUB_VLAN} \
        --kube-version $(ibmcloud ks kube-versions -s | tail -1)

    echo "Wait for the cluster to be ready"
    while ! (ibmcloud ks clusters | tee tmpout | grep "^${CLUSTER_NAME} " | grep " normal "); do
        grep "^${CLUSTER_NAME} " tmpout || true
        sleep 30
    done
    rm tmpout
fi

echo "Get the KUBECONFIG export to use"
ibmcloud config --check-version false
$(ibmcloud ks cluster-config -s --export ${CLUSTER_NAME})

install_tiller()
{
    r=$(cat /dev/urandom | env LC_CTYPE=C tr -cd 'a-f0-9' | head -c 5)
    local tiller_sa=$1-$r
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
    name: ${tiller_sa}
    namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
    name: ${tiller_sa}-role
roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: cluster-admin
subjects:
    - kind: ServiceAccount
      name: ${tiller_sa}
      namespace: kube-system
EOF
    echo tiller_sa
}

save_to_conf()
{
    local var_name=$1
    local value=$2
    if grep "$var_name=.*" ~/.out; then
        sed -i -e "s/^$var_name=.*/$var_name=$value/" ~/.out
    else
        echo "$var_name=$n" >> ~/.out
    fi
}

echo "Checking to see if tiller has been installed..."
if helm ls > /dev/null 2>&1 ; then
    echo "Helm client is working."
else
    n=$(install_tiller tiller)
    helm init --service-account $n
    save_to_conf TILLER $n
fi

if helm ls | grep ${DEPLOY_NAME} 2>&1 ; then
    echo "Deployment is found."
else
    helm install $(dirname "$0")/../charts/spark-cluster -n ${NAMESPACE}
    save_to_conf DEPLOY_NAME ${DEPLOY_NAME}
    save_to_conf NAMESPACE ${NAMESPACE}
fi

SPARK_MASTER=$(kubectl get pod -n ${NAMESPACE} | grep spark-master-controller-* | awk '{print $1}')
kubectl exec -it $SPARK_MASTER -- pyspark --driver-cores ${DRIVER_CORES} --driver-memory ${DRIVER_MEMORY} \
--num-executors ${NUM_EXECUTORS} --total-executor-cores ${TOTAL_EXECUTOR_CORES} --executor-memory ${EXECUTOR_MEMORY}