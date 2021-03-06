#!/bin/bash
# download binaries to worker

# Exit if any of the intermediate steps fail
set -e

VER_K8S=${1}
VER_CONTAINERD=${2}
VER_CNI=${3}

wget -q --show-progress --https-only --timestamping -T 15 -t 1 \
  https://github.com/containernetworking/plugins/releases/download/v${VER_CNI}/cni-plugins-amd64-v${VER_CNI}.tgz \
  https://github.com/kubernetes-incubator/cri-containerd/releases/download/v${VER_CONTAINERD}/cri-containerd-${VER_CONTAINERD}.linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v${VER_K8S}/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v${VER_K8S}/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v${VER_K8S}/bin/linux/amd64/kubelet
