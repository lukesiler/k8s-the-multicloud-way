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

### Inputs File Reference (in.json)

Name | Example | Description
--- | --- | ---
gcpProject | your-org-prj-name | Google Cloud Platform (GCP) Project to deploy in
gcpCredential | ../../secrets/gcp/yours/service_account_key.json | Relative path to GCP Service Account Key JSON.  Terraform uses this to authenticate API access to GCP.
gcpSshKeyPath | ../../secrets/ssh/k8s-the-mc-way | Relative path to SSH private key.  Terraform uses this for provisioners' access to GCP-based virtual machines.
awsSshKeyPairName | yoursurname-k8s-the-mc-way | Name of AWS EC2 key pair public key.  This gets added to VM's SSH known hosts.
awsSshKeyFileName | k8s-the-mc-way | Name of SSH private key file.  Terraform uses this for provisioners' access to AWS-based virtual machines.
awsSshKeyPath | ../../secrets/ssh | Relative path to SSH private key.  Terraform uses this for provisioners' access to AWS-based virtual machines.
awsAccessKeyIdPath | ../../secrets/aws/iam_user/access_key_id | Relative path to text file with IAM User Secret Key.  Terraform uses this to authenticate API access to AWS.
awsSecretAccessKeyPath | ../../secrets/aws/iam_user/secret_access_key | Relative path to text file with IAM User Access Key.  Terraform uses this to authenticate API access to AWS.
envPrefix | yoursurname-k8s-tmcw | Prefix to use in naming virtual machines and other cloud resources.  This helps make things easily identifiable esp. if you are sharing public cloud account with other team members.
serviceSubnetCidr | 10.32.0.0/24 | Kubernetes Service Subnet address range - used for allocation of Cluster IP's.  This range is NAT'd to pod subnet range by iptables.
podSubnetCidr | 10.200.0.0/16 | Kubernetes Pod Subnet address range - used for allocation of Pod IP's.  This range is what pods use to address each other.  Each worker gets a /24 for its local pod address range.
physicalSubnetCidr | 192.168.1.0/24 | Virtual Private Cloud Subnet address range - used for allocation of Node IP's.  All cross-node traffic ends up being routed across this network.

### MacOS

```
machine:dir user$ brew install terraform

machine:dir user$ brew install cfssl

machine:dir user$ brew install kubernetes-cli

machine:dir user$ brew install jq

machine:dir user$ git clone

# import the public key generated here into GCP Project Compute Engine Metadata SSH Keys and/or AWS Region EC2 Key Pairs
machine:dir user$ ssh-keygen -t rsa -f secrets/ssh/k8s-the-mc-way -C ssh-user

machine:dir user$ chmod 400 secrets/ssh/k8s-the-mc-way

machine:dir user$ cd k8s-the-multicloud-way

# update fields to match your GCP and/or AWS accounts
machine:dir user$ vim in.json

machine:dir user$ cd way-gcp OR cd way-aws

machine:dir user$ terraform init

machine:dir user$ terraform apply -var-file ../in.json

machine:dir user$ kubectl create your-interesting-experiments

machine:dir user$ terraform destroy -var-file ../in.json
```
