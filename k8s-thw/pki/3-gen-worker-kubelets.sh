#!/bin/bash
# generate kubelet keypair for each machine

json=$(eval "cat ../in.json")
envName=$(echo ${json} | jq -r '.env.name')
envPrefix=$(echo ${json} | jq -r '.env.prefix')
pkiAlgo=$(echo ${json} | jq -r '.pki.algo')
pkiSize=$(echo ${json} | jq -r '.pki.size')
geoCity=$(echo ${json} | jq -r '.geo.city')
geoState=$(echo ${json} | jq -r '.geo.state')
geoCountry=$(echo ${json} | jq -r '.geo.country')
workerPrimIpPrefix=$(echo ${json} | jq -r '.worker.primaryIpPrefix')
workerNameQualifier=$(echo ${json} | jq -r '.worker.nameQualifier')

for i in 0 1 2; do
hostname=${envPrefix}${workerNameQualifier}${i}
ip=${workerPrimIpPrefix}${i}
cat > ${hostname}-csr.json <<EOF
{
  "CN": "system:node:${hostname}",
  "key": {
    "algo": "${pkiAlgo}",
    "size": ${pkiSize}
  },
  "names": [
    {
      "C": "${geoCountry}",
      "L": "${geoCity}",
      "O": "system:nodes",
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
  -hostname=${hostname},${ip} \
  -profile=kubernetes \
  ${hostname}-csr.json | cfssljson -bare ${hostname}
done
