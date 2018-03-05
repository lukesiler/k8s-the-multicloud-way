#!/bin/bash
# configure RBAC policy that kubelet will use to access API server - run on only one of the masters after /healthz is successful

# do NOT exit if any of the intermediate steps fail cause curl will definitely fail in polling
#set -e

# import common functions
source ../../config/common.sh

waitForUrlOrExit http://localhost:8080/healthz
#waitForUrlOrExit http://localhost:8080/version
#waitForUrlOrExit http://localhost:8080/apis/rbac.authorization.k8s.io/v1/clusterroles
#waitForUrlOrExit http://localhost:8080/apis/rbac.authorization.k8s.io/v1/clusterrolebindings

# create kube-apiserver-to-kubelet role to allow apiserver to connect to kubelets
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autou***REMOVED***ate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

# bind kubernetes user to the role
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
