#!/bin/bash
# generate kubelet keypair for each machine

json=$(eval "cat ../in.json")
envName=$(echo ${json} | jq -r '.envName')
envPrefix=$(echo ${json} | jq -r '.envPrefix')
pkiAlgo=$(echo ${json} | jq -r '.pkiAlgo')
pkiSize=$(echo ${json} | jq -r '.pkiSize')
geoCity=$(echo ${json} | jq -r '.geoCity')
geoState=$(echo ${json} | jq -r '.geoState')
geoCountry=$(echo ${json} | jq -r '.geoCountry')
workerPrimIpPrefix=$(echo ${json} | jq -r '.workerPrimaryIpPrefix')
workerNameQualifier=$(echo ${json} | jq -r '.workerNameQualifier')

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
