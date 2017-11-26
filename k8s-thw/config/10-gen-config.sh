#!/bin/bash
ENV=siler-k8s-thw

# access api server at LB IP so it is highly available
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe ${ENV} \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')

# generate kubelet config files
for instance in ${ENV}-w-0 ${ENV}-w-1 ${ENV}-w-2; do
  kubectl config set-cluster kubernetes \
    --certificate-authority=../pki/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
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
done

# generate kube-proxy config files
kubectl config set-cluster kubernetes \
  --certificate-authority=../pki/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
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
