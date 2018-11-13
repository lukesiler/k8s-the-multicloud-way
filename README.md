# Kubernetes the Terraform Way

An implementation of 
<a href="https://github.com/kelseyhightower/kubernetes-the-hard-way">Kubernetes The Hard Way</a> that makes it easy to spin up K8S clusters quickly, peel the onion layers to understand exactly the steps involved, and change things up to try something different or new.

## Tools

<a href="https://www.terraform.io/">Terraform</a> for infrastructure control as code - network, compute, firewall, LB, etc.

<a href="https://github.com/cloudflare/cfssl">CloudFlare's PKI/TLS Toolkit</a> for <a href="https://en.wikipedia.org/wiki/Public_key_infrastructure">PKI</a>.

<a href="https://github.com/cloudflare/cfssl">bash</a> for bootstrap configuration as invoked by <a href="https://www.terraform.io/docs/provisioners/index.html">Terraform SSH/SCP remote provisioners</a>.

<a href="https://stedolan.github.io/jq/">jq</a> for bash-based JSON parsing of in.json which is also Terraform input variable file.

Ways now implemented are Google Cloud Platform (GCP) and Amazon Web Services (AWS).  vCenter-managed vSphere will be next.

## Try It

Basic instructions to try this out yourself.  You'll need to configure **in.json** to point to your SSH and IAM private keys and also recommend changing **envPrefix** to identify your infrastructure resources. 

### MacOS

```
machine:dir user$ brew install terraform

machine:dir user$ brew install cfssl

machine:dir user$ brew install kubernetes-cli

machine:dir user$ brew install jq

machine:dir user$ git clone ;cd k8s-the-multicloud-way

machine:dir user$ ssh-keygen -t rsa -f k8s-the-mc-way -C ssh-user

machine:dir user$ chmod 400 k8s-the-mc-way

machine:dir user$ import public key into GCP Project and/or AWS Region

# u***REMOVED***ate fields to match your GCP and/or AWS accounts
machine:dir user$ vim in.json

machine:dir user$ cd way-gcp OR cd way-aws

machine:dir user$ terraform init

machine:dir user$ terraform apply -var-file ../in.json

machine:dir user$ kubectl create your-interesting-experiments

machine:dir user$ terraform destroy -var-file ../in.json
```
