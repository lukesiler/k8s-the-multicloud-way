#!/bin/bash
# download binaries to master

# Exit if any of the intermediate steps fail
set -e

VER_ETCD=${1}
VER_K8S=${2}

wget -q --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/v${VER_ETCD}/etcd-v${VER_ETCD}-linux-amd64.tar.gz" \
  "https://storage.googleapis.com/kubernetes-release/release/v${VER_K8S}/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v${VER_K8S}/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v${VER_K8S}/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v${VER_K8S}/bin/linux/amd64/kubectl"
