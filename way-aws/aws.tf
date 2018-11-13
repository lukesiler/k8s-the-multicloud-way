variable "awsRegion" {
}
variable "awsZone" {
}
variable "awsMachineType" {
}
variable "awsMachineImage" {
  # ubuntu 16.04 LTS hvm:ebs-ssd
  default = "ami-965e6bf3"
}
variable "awsVpcCidr" {
}
variable "awsAccessKeyIdPath" {
}
variable "awsSecretAccessKeyPath" {
}
variable "awsSshKeyPairName" {
}
variable "awsSshKeyFileName" {
}
variable "awsSshKeyPath" {
}

variable "envPrefix" {
}
variable "envName" {
}

variable "physicalSubnetCidr" {
}
variable "masterPrimaryIpPrefix" {
}
variable "workerPrimaryIpPrefix" {
}

variable "masterNameQualifier" {
}

variable "masterApiServerPort" {
}

variable "workerNameQualifier" {
}

variable "podSubnetCidr" {
}
variable "podSubnetPrefix" {
}
variable "podSubnetSuffix" {
}

variable "serviceSubnetCidr" {
}
variable "serviceClusterKubeDns" {
}

variable "verEtcd" {
}
variable "verK8s" {
}
variable "verContainerd" {
}
variable "verCni" {
}

variable "keypairs" {
  default = {
    "ca" = "ca"
    "api" = "kubernetes"
  }
}

variable "awsSshUser" {
}

variable "masterCount" {
}
variable "workerCount" {
}

provider "aws" {
  access_key = "${trimspace(file("${var.awsAccessKeyIdPath}"))}"
  secret_key = "${trimspace(file("${var.awsSecretAccessKeyPath}"))}"
  region     = "${var.awsRegion}"
}

resource "aws_vpc" "net" {
  cidr_block = "${var.awsVpcCidr}"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags {
    Name = "${var.envPrefix}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.net.id}"
}

resource "aws_route" "igw-route" {
  route_table_id            = "${aws_vpc.net.default_route_table_id}"
  gateway_id                = "${aws_internet_gateway.igw.id}"
  destination_cidr_block    = "0.0.0.0/0"
}

resource "aws_subnet" "subnet-nodes" {
  vpc_id     = "${aws_vpc.net.id}"
  cidr_block = "${var.physicalSubnetCidr}"
  availability_zone = "${var.awsRegion}${var.awsZone}"
  map_public_ip_on_launch = true

  tags {
    Name = "${var.envPrefix}"
  }
}

resource "aws_security_group" "allow-enough" {
  name        = "allow-enough"
  description = "Allow enough traffic"
  vpc_id      = "${aws_vpc.net.id}"

  # allow internal TCP on physical and pod subnets
  ingress {
    from_port = 0
    to_port = 65535
    protocol    = "tcp"
    cidr_blocks = ["${var.physicalSubnetCidr}", "${var.podSubnetCidr}"]
  }
  egress {
    from_port = 0
    to_port = 65535
    protocol    = "tcp"
    cidr_blocks = ["${var.physicalSubnetCidr}", "${var.podSubnetCidr}"]
  }

  # allow internal UDP on physical and pod subnets
  ingress {
    from_port = 0
    to_port = 65535
    protocol    = "udp"
    cidr_blocks = ["${var.physicalSubnetCidr}", "${var.podSubnetCidr}"]
  }
  egress {
    from_port = 0
    to_port = 65535
    protocol    = "udp"
    cidr_blocks = ["${var.physicalSubnetCidr}", "${var.podSubnetCidr}"]
  }

  # allow inbound access to SSH
  ingress {
    from_port = 22
    to_port = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow inbound access to API server
  ingress {
    from_port = "${var.masterApiServerPort}"
    to_port = "${var.masterApiServerPort}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow download of binaries
  egress {
    from_port = 443
    to_port = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow worker interaction w/ API server on NLB IP
  egress {
    from_port = 6443
    to_port = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# teardown bug addressed by building plug-in from source - https://github.com/terraform-providers/terraform-provider-aws/pull/1956
resource "aws_eip" "api-server" {
  vpc      = true

  tags {
    Name = "${var.envPrefix}"
  }
}

resource "null_resource" "pki-keypairs" {
  provisioner "local-exec" {
    # make sure perms on ssh private key match AWS' requirements - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/TroubleshootingInstancesConnecting.html#TroubleshootingInstancesConnectingMindTerm
    command = "chmod 400 ${var.awsSshKeyPath}/${var.awsSshKeyFileName}"
  }
  provisioner "local-exec" {
    command = "mkdir -p pki config;rm -f pki/* config/*"
  }
  provisioner "local-exec" {
    command = "cd pki;../../pki/1-gen-ca.sh"
  }
  provisioner "local-exec" {
    command = "cd pki;../../pki/2-gen-admin.sh"
  }
  provisioner "local-exec" {
    command = "cd pki;../../pki/3-gen-worker-kubelets.sh ${var.workerCount}"
  }
  provisioner "local-exec" {
    command = "cd pki;../../pki/4-gen-kube-proxy.sh"
  }
  provisioner "local-exec" {
    command = "cd pki;../../pki/5-gen-kube-api-server.sh ${aws_eip.api-server.public_ip}"
  }
  provisioner "local-exec" {
    command = "cd pki;../../pki/6-gen-encrypt-key.sh"
  }
  provisioner "local-exec" {
    command = "cd config;../../config/07-gen-worker-config.sh ${aws_eip.api-server.public_ip} ${var.workerCount}"
  }
}

resource "aws_instance" "master-nodes" {
  count         = "${var.masterCount}"
  ami           = "${var.awsMachineImage}"
  instance_type = "${var.awsMachineType}"
  subnet_id     = "${aws_subnet.subnet-nodes.id}"
  associate_public_ip_address = true
  source_dest_check = false
  private_ip = "${var.masterPrimaryIpPrefix}${count.index}"
  key_name = "${var.awsSshKeyPairName}"

  vpc_security_group_ids = [
    "${aws_security_group.allow-enough.id}"
  ]

  tags {
    Name = "${var.envPrefix}${var.masterNameQualifier}${count.index}"
  }

  volume_tags {
    Name = "${var.envPrefix}${var.masterNameQualifier}${count.index}"
  }

  depends_on = ["aws_internet_gateway.igw", "null_resource.pki-keypairs"]

  provisioner "file" {
    source      = "pki/${var.keypairs["ca"]}.pem"
    destination = "${var.keypairs["ca"]}.pem"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.keypairs["ca"]}-key.pem"
    destination = "${var.keypairs["ca"]}-key.pem"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.keypairs["api"]}.pem"
    destination = "${var.keypairs["api"]}.pem"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.keypairs["api"]}-key.pem"
    destination = "${var.keypairs["api"]}-key.pem"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "pki/encryption-config.yaml"
    destination = "encryption-config.yaml"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "../config/08-get-master-bits.sh"
    destination = "08-get-master-bits.sh"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "../config/09-setup-etcd.sh"
    destination = "09-setup-etcd.sh"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "../config/10-setup-k8s-ctrl.sh"
    destination = "10-setup-k8s-ctrl.sh"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "sudo hostname ${var.envPrefix}${var.masterNameQualifier}${count.index}",
      "chmod +x ~/*.sh",
      "~/08-get-master-bits.sh ${var.verEtcd} ${var.verK8s}",
      "~/09-setup-etcd.sh ${count.index} ${var.masterPrimaryIpPrefix} ${var.masterNameQualifier}",
      "~/10-setup-k8s-ctrl.sh ${count.index} ${var.masterPrimaryIpPrefix} ${var.serviceSubnetCidr} ${var.podSubnetCidr}"
    ]

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
}

resource "aws_eip_association" "master-node0-public-ip" {
  instance_id   = "${aws_instance.master-nodes.0.id}"
  allocation_id = "${aws_eip.api-server.id}"
}

resource "null_resource" "master-nodes-api-rbac" {
  # run RBAC config on just one of the masters after waiting for k8s API healthz

  provisioner "file" {
    source      = "../config/11-config-rbac-kubelet.sh"
    destination = "11-config-rbac-kubelet.sh"

    connection {
      // use index of the last master node for best chance that others are up and configured
      host     = "${aws_instance.master-nodes.2.public_ip}"
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }

  provisioner "file" {
    source      = "../config/common.sh"
    destination = "common.sh"

    connection {
      // use index of the last master node for best chance that others are up and configured
      host     = "${aws_instance.master-nodes.2.public_ip}"
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/common.sh",
      "chmod +x ~/11-config-rbac-kubelet.sh",
      "~/11-config-rbac-kubelet.sh"
    ]

    connection {
      // use index of the last master node for best chance that others are up and configured
      host     = "${aws_instance.master-nodes.2.public_ip}"
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
}

resource "aws_instance" "worker-nodes" {
  count         = "${var.workerCount}"
  ami           = "${var.awsMachineImage}"
  instance_type = "${var.awsMachineType}"
  subnet_id     = "${aws_subnet.subnet-nodes.id}"
  associate_public_ip_address = true
  source_dest_check = false
  private_ip = "${var.workerPrimaryIpPrefix}${count.index}"
  key_name = "${var.awsSshKeyPairName}"

  vpc_security_group_ids = [
    "${aws_security_group.allow-enough.id}"
  ]

  tags {
    Name = "${var.envPrefix}${var.workerNameQualifier}${count.index}"
  }

  volume_tags {
    Name = "${var.envPrefix}${var.workerNameQualifier}${count.index}"
  }

  depends_on = ["aws_internet_gateway.igw"]

  provisioner "file" {
    source      = "pki/${var.keypairs["ca"]}.pem"
    destination = "${var.keypairs["ca"]}.pem"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.envPrefix}${var.workerNameQualifier}${count.index}.pem"
    destination = "${var.envPrefix}${var.workerNameQualifier}${count.index}.pem"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.envPrefix}${var.workerNameQualifier}${count.index}-key.pem"
    destination = "${var.envPrefix}${var.workerNameQualifier}${count.index}-key.pem"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "config/${var.envPrefix}${var.workerNameQualifier}${count.index}.kubeconfig"
    destination = "${var.envPrefix}${var.workerNameQualifier}${count.index}.kubeconfig"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "config/kube-proxy.kubeconfig"
    destination = "kube-proxy.kubeconfig"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "config/kube-proxy.kubeconfig"
    destination = "kube-proxy.kubeconfig"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "../config/12-get-worker-bits.sh"
    destination = "12-get-worker-bits.sh"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "../config/13-install-worker-bits.sh"
    destination = "13-install-worker-bits.sh"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "file" {
    source      = "../config/14-config-worker.sh"
    destination = "14-config-worker.sh"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
  provisioner "remote-exec" {
    inline = [
      # make hostname match cert for mTLS
      # TODO: switch to cloud-init for this - https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux_OpenStack_Platform/4/html/End_User_Guide/user-data.html and https://github.com/hashicorp/terraform/issues/1893
      "sudo hostname ${var.envPrefix}${var.workerNameQualifier}${count.index}",
      "sudo apt-get -y install socat",
      "chmod +x ~/*.sh",
      "./12-get-worker-bits.sh ${var.verK8s} ${var.verContainerd} ${var.verCni}",
      "./13-install-worker-bits.sh",
      "./14-config-worker.sh ${var.envPrefix}${var.workerNameQualifier}${count.index} ${var.serviceClusterKubeDns} ${var.podSubnetCidr} ${var.podSubnetPrefix}${count.index}${var.podSubnetSuffix}"
    ]

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyFileName}")}"
    }
  }
}

resource "aws_route" "worker-pod-route" {
  count                     = "${var.workerCount}"
  route_table_id            = "${aws_vpc.net.default_route_table_id}"
  destination_cidr_block    = "${var.podSubnetPrefix}${count.index}${var.podSubnetSuffix}"
  instance_id               = "${element(aws_instance.worker-nodes.*.id, count.index)}"
}

resource "null_resource" "finish-up" {

  # Wait for worker pod routes to be created
  depends_on = ["aws_route.worker-pod-route", "aws_eip_association.master-node0-public-ip"]

  # run RBAC config on just one of the masters after waiting for k8s API healthz
  provisioner "local-exec" {
    command = "cd config;../../config/15-setup-kubectl-local.sh ${var.envPrefix} ${aws_eip.api-server.public_ip} ${var.masterApiServerPort} aws"
  }
  provisioner "local-exec" {
    command = "cd config;../../config/16-setup-dns.sh ${var.serviceClusterKubeDns} ${aws_eip.api-server.public_ip} ${var.masterApiServerPort}"
  }
}

/**
# due to limitation in NLB terraform API (see github links) and slowness of NLB provisioning, this has been dropped to just associate EIP with a master node directly
resource "aws_lb" "api-server" {
  # NLB sits in provisioning for minutes - very slow
  name            = "${var.envPrefix}"
  internal        = false
  load_balancer_type = "network"
  enable_deletion_protection = false
  ip_address_type = "ipv4"

  subnet_mapping {
    subnet_id = "${aws_subnet.subnet-nodes.id}"
    allocation_id = "${aws_eip.api-server.id}"
  }

  depends_on = ["aws_eip.api-server"]
}

resource "aws_lb_target_group" "api-server" {
  name    = "${var.envPrefix}"
  port     = "${var.masterApiServerPort}"
  protocol = "TCP"
  vpc_id   = "${aws_vpc.net.id}"
  target_type = "instance"

  health_check {
    # reporting unhealthy - due to TLS handshake?
    # 10 or 30 are the supported options
    interval = 10
  }
}

resource "aws_lb_target_group_attachment" "master-node-0" {
  target_group_arn = "${aws_lb_target_group.api-server.arn}"
  # need a hack to get all three - https://github.com/hashicorp/terraform/pull/9986 and https://github.com/terraform-providers/terraform-provider-aws/pull/1726
  target_id        = "${aws_instance.master-nodes.0.id}"
  port             = "${var.masterApiServerPort}"
}

resource "aws_lb_listener" "api-server" {
  load_balancer_arn = "${aws_lb.api-server.arn}"
  port              = "${var.masterApiServerPort}"
  protocol          = "TCP"

  default_action {
    target_group_arn = "${aws_lb_target_group.api-server.arn}"
    type             = "forward"
  }

  provisioner "local-exec" {
    command = "cd config;../../config/15-setup-kubectl-local.sh ${var.envPrefix} ${aws_eip.api-server.public_ip} ${var.masterApiServerPort}"
  }
  provisioner "local-exec" {
    command = "cd config;../../config/16-setup-dns.sh ${var.serviceClusterKubeDns} ${aws_eip.api-server.public_ip} ${var.masterApiServerPort}"
  }
}
*/

output "api-server-address" {
 value = "${aws_eip.api-server.public_ip}"
}
output "api-server-curl" {
 value = "curl --cacert pki/ca.pem https://${aws_eip.api-server.public_ip}:${var.masterApiServerPort}/version"
}
# mac curl has trouble with PEM format
output "convert-to-pkcs12-for-mac-curl" {
 value = "openssl pkcs12 -export -in pki/admin.pem -inkey pki/admin-key.pem -out pki/admin.p12"
}
output "curl-as-admin" {
 value = "curl --cacert pki/ca.pem --cert pki/admin.pem --key pki/admin-key.pem https://${aws_eip.api-server.public_ip}:${var.masterApiServerPort}/api/v1/nodes"
}
output "create-servers" {
  value = "kubectl run whoami --kubeconfig=kubectl-config --replicas=3 --labels=\"run=server-example\" --image=emilevauge/whoami  --port=8081"
}
output "all-pods" {
  value = "kubectl get pod -o wide --kubeconfig=kubectl-config --all-namespaces"
}
output "ssh-to-master0" {
  value = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.awsSshKeyPath}/${var.awsSshKeyFileName} ${var.awsSshUser}@${element(aws_instance.master-nodes.*.public_ip, 0)}"
}
output "ssh-to-worker0" {
  value = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.awsSshKeyPath}/${var.awsSshKeyFileName} ${var.awsSshUser}@${element(aws_instance.worker-nodes.*.public_ip, 0)}"
}
output "kubelet-logs" {
  value = "journalctl -u kubelet.service | less"
}