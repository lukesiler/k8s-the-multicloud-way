#!/bin/bash
json=$(eval "cat ../in.json")
envId=$(echo ${json} | jq -r '.env.id')
pkiAlgo=$(echo ${json} | jq -r '.pki.algo')
pkiSize=$(echo ${json} | jq -r '.pki.size')
geoCity=$(echo ${json} | jq -r '.geo.city')
geoState=$(echo ${json} | jq -r '.geo.state')
geoCountry=$(echo ${json} | jq -r '.geo.country')

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
