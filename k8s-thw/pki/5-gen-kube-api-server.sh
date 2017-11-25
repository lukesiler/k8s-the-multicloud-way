#!/bin/bash
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe siler-k8s-thw \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
