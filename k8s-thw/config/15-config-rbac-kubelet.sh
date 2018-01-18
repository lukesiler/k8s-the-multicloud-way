#!/bin/bash
# configure RBAC policy that kubelet will use to access API server - run on only one of the masters after /healthz is successful

# print messages with timestamp prefix
msg() {
    echo >&2 -e `date "+%F %T"` $@
}

# This waits for a url to be available by querying once a second for
# specified number of seconds.
#
# @param ${1}: url to test
# @param ${2}: Number of seconds. Optional argument, defaults to 30
#
# If the url doesn't respond, we fail.
waitForUrl() {
    url=${1}
    secondsToTry=${2}

    if [ -z "${secondsToTry}" ]; then
        secondsToTry=30
    fi

    msg "Waiting for ${url} for up to ${secondsToTry} seconds..."

    attempt=0
    while [ ${attempt} -lt ${secondsToTry} ]; do
        statuscode=$(curl --silent --output /dev/null --write-out "%{http_code}" ${url})
        if test ${statuscode} -eq 200; then
            msg "GET ok"
            return 0
        fi
        sleep 1
        attempt=`expr ${attempt} + 1`
    done
    msg "ERROR: ${url} is not responding"
    return 1
}

waitForUrlOrExit() {
    url=$1
    secondsToTry=$2

    waitForUrl ${url} ${secondsToTry}
    rc=$?
    if [ ${rc} -ne 0 ]; then
        msg "Wait for k8s control plane failed!"
        exit 1
    fi
}

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
