#!/bin/bash
# generate admin user keypair

json=$(eval "cat ../../in.json")
envName=$(echo ${json} | jq -r '.envName')
pkiAlgo=$(echo ${json} | jq -r '.pkiAlgo')
pkiSize=$(echo ${json} | jq -r '.pkiSize')
geoCity=$(echo ${json} | jq -r '.geoCity')
geoState=$(echo ${json} | jq -r '.geoState')
geoCountry=$(echo ${json} | jq -r '.geoCountry')

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "${pkiAlgo}",
    "size": ${pkiSize}
  },
  "names": [
    {
      "C": "${geoCountry}",
      "L": "${geoCity}",
      "O": "system:masters",
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
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin
