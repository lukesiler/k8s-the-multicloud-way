#!/bin/bash
# install binaries to worker

# Exit if any of the intermediate steps fail
set -e

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

sudo tar -xvf cni-plugins-amd64-v*.tgz -C /opt/cni/bin/

sudo tar -xvf cri-containerd-*.tar.gz -C /

chmod +x kubectl kube-proxy kubelet

sudo mv kubectl kube-proxy kubelet /usr/local/bin/
