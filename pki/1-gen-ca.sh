#!/bin/bash
# generate CA root

json=$(eval "cat ../in.json")
envId=$(echo ${json} | jq -r '.envId')
pkiAlgo=$(echo ${json} | jq -r '.pkiAlgo')
pkiSize=$(echo ${json} | jq -r '.pkiSize')
geoCity=$(echo ${json} | jq -r '.geoCity')
geoState=$(echo ${json} | jq -r '.geoState')
geoCountry=$(echo ${json} | jq -r '.geoCountry')

cat > ca-csr.json <<EOF
{
  "CN": "${envId}",
  "key": {
    "algo": "${pkiAlgo}",
    "size": ${pkiSize}
  },
  "names": [
    {
      "C": "${geoCountry}",
      "L": "${geoCity}",
      "O": "${envId}",
      "OU": "CA",
      "ST": "${geoState}"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
