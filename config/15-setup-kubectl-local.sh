#!/bin/bash
# configure local kubectl to interact with cluster just created and configured

# Exit if any of the intermediate steps fail
set -e

ENV=${1}
KUBERNETES_PUBLIC_ADDRESS=${2}
KUBERNETES_API_PORT=${3}
WAY=${4}

# get the way as disambiguator of kubectl context for cluster so the ways can live side-by-side
CLUSTER=${ENV}-${WAY}

cat /dev/null > ../kubectl-config

kubectl config --kubeconfig=../kubectl-config \
  set-cluster ${CLUSTER} \
  --certificate-authority=../pki/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:${KUBERNETES_API_PORT}

kubectl config --kubeconfig=../kubectl-config \
  set-credentials ${CLUSTER}-admin \
  --client-certificate=../pki/admin.pem \
  --client-key=../pki/admin-key.pem

kubectl config --kubeconfig=../kubectl-config \
  set-context ${CLUSTER} \
  --cluster=${CLUSTER} \
  --user=${CLUSTER}-admin

kubectl config --kubeconfig=../kubectl-config \
  use-context ${CLUSTER}
