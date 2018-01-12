#!/bin/bash
hostname-prefix=siler-k8s-thw-w-
algo=rsa
size=2048
country=US
city=Shoreline
state=Washington
ip-prefix=10.240.0.2

for i in 0 1 2; do
hostname=${hostname-prefix}${i}
cat > ${hostname}-csr.json <<EOF
{
  "CN": "system:node:${hostname}",
  "key": {
    "algo": "${algo}",
    "size": ${size}
  },
  "names": [
    {
      "C": "${country}",
      "L": "${city}",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "${state}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${hostname},${ip-prefix}${i} \
  -profile=kubernetes \
  ${hostname}-csr.json | cfssljson -bare ${hostname}
done
