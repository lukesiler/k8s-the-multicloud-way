#!/bin/bash
# generate kube API server keypair

# Exit if any of the intermediate steps fail
set -e

KUBERNETES_PUBLIC_ADDRESS=${1}

json=$(eval "cat ../../in.json")
envId=$(echo ${json} | jq -r '.envId')
envName=$(echo ${json} | jq -r '.envName')
pkiAlgo=$(echo ${json} | jq -r '.pkiAlgo')
pkiSize=$(echo ${json} | jq -r '.pkiSize')
geoCity=$(echo ${json} | jq -r '.geoCity')
geoState=$(echo ${json} | jq -r '.geoState')
geoCountry=$(echo ${json} | jq -r '.geoCountry')
masterPrimIpPrefix=$(echo ${json} | jq -r '.masterPrimaryIpPrefix')
serviceClusterKubeApi=$(echo ${json} | jq -r '.serviceClusterKubeApi')

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "${pkiAlgo}",
    "size": ${pkiSize}
  },
  "names": [
    {
      "C": "${geoCountry}",
      "L": "${geoCity}",
      "O": "${envId}",
      "OU": "${envName}",
      "ST": "${geoState}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=../../pki/ca-config.json \
  -hostname=${serviceClusterKubeApi},${masterPrimIpPrefix}0,${masterPrimIpPrefix}1,${masterPrimIpPrefix}2,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
