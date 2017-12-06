#!/bin/bash

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

sudo tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/

sudo tar -xvf cri-containerd-1.0.0-alpha.0.tar.gz -C /

chmod +x kubectl kube-proxy kubelet

sudo mv kubectl kube-proxy kubelet /usr/local/bin/
