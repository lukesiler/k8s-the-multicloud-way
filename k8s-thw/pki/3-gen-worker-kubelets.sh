#!/bin/bash
for i in 0 1 2; do
prefix=siler-k8s-thw-w-
cat > ${prefix}${i}-csr.json <<EOF
{
  "CN": "system:node:${prefix}${i}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Shoreline",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Washington"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${prefix}${i},10.240.0.2${i} \
  -profile=kubernetes \
  ${prefix}${i}-csr.json | cfssljson -bare ${prefix}${i}
done
