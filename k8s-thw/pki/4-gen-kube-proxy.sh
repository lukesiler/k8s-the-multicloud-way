#!/bin/bash
json=$(eval "cat ../in.json")
envName=$(echo ${json} | jq -r '.env.name')
envPrefix=$(echo ${json} | jq -r '.env.prefix')
pkiAlgo=$(echo ${json} | jq -r '.pki.algo')
pkiSize=$(echo ${json} | jq -r '.pki.size')
geoCity=$(echo ${json} | jq -r '.geo.city')
geoState=$(echo ${json} | jq -r '.geo.state')
geoCountry=$(echo ${json} | jq -r '.geo.country')
workerPrimIpPrefix=$(echo ${json} | jq -r '.worker.primaryIpPrefix')

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "${pkiAlgo}",
    "size": ${pkiSize}
  },
  "names": [
    {
      "C": "${geoCountry}",
      "L": "${geoCity}",
      "O": "system:node-proxier",
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
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy
