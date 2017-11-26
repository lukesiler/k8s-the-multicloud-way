#!/bin/bash
# put CA keypair and API Server keypair on each master
prefix=siler-k8s-thw-m-
for i in 0 1 2; do
  gcloud compute scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem ${instance}:~/
done
