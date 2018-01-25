#!/bin/bash
# configure local kubectl to interact with cluster just created and configured

ENV=${1}
KUBERNETES_PUBLIC_ADDRESS=${2}
KUBERNETES_API_PORT=${3}

kubectl config set-cluster ${ENV} \
  --certificate-authority=../pki/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:${KUBERNETES_API_PORT}

kubectl config set-credentials admin \
  --client-certificate=../pki/admin.pem \
  --client-key=../pki/admin-key.pem

kubectl config set-context ${ENV} \
  --cluster=${ENV} \
  --user=admin

kubectl config use-context ${ENV}
