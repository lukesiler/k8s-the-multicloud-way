#!/bin/bash
# generate kube API server keypair

KUBERNETES_PUBLIC_ADDRESS=${1}

json=$(eval "cat ../in.json")
envId=$(echo ${json} | jq -r '.env.id')
envName=$(echo ${json} | jq -r '.env.name')
pkiAlgo=$(echo ${json} | jq -r '.pki.algo')
pkiSize=$(echo ${json} | jq -r '.pki.size')
geoCity=$(echo ${json} | jq -r '.geo.city')
geoState=$(echo ${json} | jq -r '.geo.state')
geoCountry=$(echo ${json} | jq -r '.geo.country')
masterPrimIpPrefix=$(echo ${json} | jq -r '.master.primaryIpPrefix')
serviceNetPrefix=$(echo ${json} | jq -r '.master.serviceNetPrefix')

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
  -config=ca-config.json \
  -hostname=${serviceNetPrefix}1,${masterPrimIpPrefix}0,${masterPrimIpPrefix}1,${masterPrimIpPrefix}2,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
