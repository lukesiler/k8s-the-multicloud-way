#!/bin/bash
ENV=siler-k8s-thw
# distribute config for encrypting secrets at rest
for instance in ${ENV}-m-0 ${ENV}-m-1 ${ENV}-m-2; do
  gcloud compute scp encryption-config.yaml ${instance}:~/
done
