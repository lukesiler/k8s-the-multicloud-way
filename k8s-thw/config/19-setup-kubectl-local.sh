#!/bin/bash
# configure local kubectl to interact with cluster just created and configured

ENV=siler-k8s-thw

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe ${ENV} \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')

kubectl config set-cluster ${ENV} \
  --certificate-authority=../pki/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443

kubectl config set-credentials admin \
  --client-certificate=../pki/admin.pem \
  --client-key=../pki/admin-key.pem

kubectl config set-context ${ENV} \
  --cluster=${ENV} \
  --user=admin

kubectl config use-context ${ENV}
