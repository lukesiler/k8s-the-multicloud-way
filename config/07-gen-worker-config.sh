#!/bin/bash
# generate kubelet and kubeproxy config files for workers

# Exit if any of the intermediate steps fail
set -e

json=$(eval "cat ../../in.json")
envPrefix=$(echo ${json} | jq -r '.envPrefix')
apiServerPort=$(echo ${json} | jq -r '.masterApiServerPort')
workerNameQualifier=$(echo ${json} | jq -r '.workerNameQualifier')

# access api server at LB IP so it is highly available
KUBERNETES_PUBLIC_ADDRESS=${1}
WORKER_COUNT=${2}

prefix=${envPrefix}${workerNameQualifier}

# generate kubelet config files
i=0
while [ ${i} -lt ${WORKER_COUNT} ]; do
  instance=${prefix}${i}

  kubectl config set-cluster kubernetes \
    --certificate-authority=../pki/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:${apiServerPort} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=../pki/${instance}.pem \
    --client-key=../pki/${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig

  (( i++ ))
done

# generate kube-proxy config files
kubectl config set-cluster kubernetes \
  --certificate-authority=../pki/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:${apiServerPort} \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config set-credentials kube-proxy \
  --client-certificate=../pki/kube-proxy.pem \
  --client-key=../pki/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
