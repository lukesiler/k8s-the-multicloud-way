#!/bin/bash
ENV=siler-k8s-thw
for instance in ${ENV}-w-0 ${ENV}-w-1 ${ENV}-w-2; do
  gcloud compute scp ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}:~/
done
