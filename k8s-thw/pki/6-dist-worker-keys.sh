#!/bin/bash
# put CA public key and worker kubelet keypair on each
prefix=siler-k8s-thw-w-
for i in 0 1 2; do
  gcloud compute scp ca.pem ${prefix}${i}-key.pem ${prefix}${i}.pem ${prefix}${i}:~/
done
