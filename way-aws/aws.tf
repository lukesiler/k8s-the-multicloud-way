variable "awsRegion" {
  default = "us-east-2"
}
variable "awsZone" {
  default = "b"
}
variable "awsMachineType" {
  default = "t2.medium"
}
variable "awsMachineImage" {
  default = "ami-965e6bf3"
}
variable "awsVpcCidr" {
  default = "192.168.0.0/16"
}
variable "awsAccessKeyIdPath" {
  default = "../../secrets/aws/***REMOVED***@***REMOVED***.com/luke/access_key_id"
}
variable "awsSecretAccessKeyPath" {
  default = "../../secrets/aws/***REMOVED***@***REMOVED***.com/luke/secret_access_key"
}
variable "awsSshKeyName" {
}
variable "awsSshKeyPath" {
}

variable "envPrefix" {
  default = "siler-k8s-thw"
}
variable "envName" {
  default = "Kubernetes The Hard Way"
}

variable "physicalSubnetCidr" {
  default = "192.168.1.0/24"
}
variable "masterPrimaryIpPrefix" {
  default = "192.168.1.1"
}
variable "workerPrimaryIpPrefix" {
  default = "192.168.1.2"
}

variable "masterNameQualifier" {
  default = "-m-"
}

variable "masterApiServerPort" {
  default = "6443"
}

variable "workerNameQualifier" {
  default = "-w-"
}

variable "podSubnetCidr" {
  default = "10.200.0.0/16"
}
variable "podSubnetPrefix" {
  default = "10.200."
}
variable "podSubnetSuffix" {
  default = ".0/24"
}

variable "serviceSubnetCidr" {
  default = "10.32.0.0/24"
}
variable "serviceClusterKubeDns" {
  default = "10.32.0.10"
}

variable "verEtcd" {
  default = "3.2.8"
}
variable "verK8s" {
  default = "1.8.0"
}
variable "verContainerd" {
  default = "1.0.0-alpha.0"
}
variable "verCni" {
  default = "0.6.0"
}

variable "keypairs" {
  default = {
    "ca" = "ca"
    "api" = "kubernetes"
  }
}

variable "awsSshUser" {
  default = "ubuntu"
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

resource "aws_default_route_table" "igw-route" {
  default_route_table_id = "${aws_vpc.net.default_route_table_id}"

  route {
    gateway_id = "${aws_internet_gateway.igw.id}"
    cidr_block = "0.0.0.0/0"
  }

  tags {
    Name = "${var.envPrefix}"
  }
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
}

resource "aws_eip" "api-server" {
  vpc      = true

  tags {
    Name = "${var.envPrefix}"
  }
}

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
  value = "kubectl run whoami --replicas=3 --labels=\"run=server-example\" --image=emilevauge/whoami  --port=8081"
}
output "all-pods" {
  value = "kubectl get pod -o wide --all-namespaces"
}

resource "null_resource" "pki-keypairs" {
  count = "1"

  provisioner "local-exec" {
    # make sure perms on ssh private key match AWS' requirements - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/TroubleshootingInstancesConnecting.html#TroubleshootingInstancesConnectingMindTerm
    command = "chmod 400 ${var.awsSshKeyPath}/${var.awsSshKeyName}.pem"
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
    command = "cd pki;../../pki/3-gen-worker-kubelets.sh"
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
    command = "cd config;../../config/07-gen-worker-config.sh ${aws_eip.api-server.public_ip}"
  }
}

resource "aws_instance" "master-nodes" {
  count = "3"
  ami           = "${var.awsMachineImage}"
  instance_type = "${var.awsMachineType}"
  subnet_id     = "${aws_subnet.subnet-nodes.id}"
  associate_public_ip_address = true
  source_dest_check = false
  private_ip = "${var.masterPrimaryIpPrefix}${count.index}"
  key_name = "${var.awsSshKeyName}"

  vpc_security_group_ids = [
    "${aws_security_group.allow-enough.id}"
  ]

  tags {
    Name = "${var.envPrefix}${var.masterNameQualifier}${count.index}"
  }

  volume_tags {
    Name = "${var.envPrefix}${var.masterNameQualifier}${count.index}"
  }

  depends_on = ["aws_internet_gateway.igw"]

  provisioner "file" {
    source      = "pki/${var.keypairs["ca"]}.pem"
    destination = "${var.keypairs["ca"]}.pem"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.keypairs["ca"]}-key.pem"
    destination = "${var.keypairs["ca"]}-key.pem"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.keypairs["api"]}.pem"
    destination = "${var.keypairs["api"]}.pem"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.keypairs["api"]}-key.pem"
    destination = "${var.keypairs["api"]}-key.pem"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "pki/encryption-config.yaml"
    destination = "encryption-config.yaml"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "../config/08-get-master-bits.sh"
    destination = "08-get-master-bits.sh"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "../config/09-setup-etcd.sh"
    destination = "09-setup-etcd.sh"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "../config/10-setup-k8s-ctrl.sh"
    destination = "10-setup-k8s-ctrl.sh"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/*.sh",
      "~/08-get-master-bits.sh ${var.verEtcd} ${var.verK8s}",
      "~/09-setup-etcd.sh ${count.index} ${var.masterPrimaryIpPrefix} ${var.masterNameQualifier}",
      "~/10-setup-k8s-ctrl.sh ${count.index} ${var.masterPrimaryIpPrefix} ${var.serviceSubnetCidr} ${var.podSubnetCidr}"
    ]

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
}

resource "null_resource" "master-nodes-api-rbac" {
  # run RBAC config on just one of the masters after waiting for k8s API healthz
  count = "1"

  provisioner "file" {
    source      = "../config/11-config-rbac-kubelet.sh"
    destination = "11-config-rbac-kubelet.sh"

    connection {
      // use index of the last master node for best chance that others are up and configured
      host     = "${aws_instance.master-nodes.2.public_ip}"
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/11-config-rbac-kubelet.sh",
      "~/11-config-rbac-kubelet.sh"
    ]

    connection {
      // use index of the last master node for best chance that others are up and configured
      host     = "${aws_instance.master-nodes.2.public_ip}"
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
}

resource "aws_instance" "worker-nodes" {
  count = "3"
  ami           = "${var.awsMachineImage}"
  instance_type = "${var.awsMachineType}"
  subnet_id     = "${aws_subnet.subnet-nodes.id}"
  associate_public_ip_address = true
  source_dest_check = false
  private_ip = "${var.workerPrimaryIpPrefix}${count.index}"
  key_name = "${var.awsSshKeyName}"

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
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.envPrefix}${var.workerNameQualifier}${count.index}.pem"
    destination = "${var.envPrefix}${var.workerNameQualifier}${count.index}.pem"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.envPrefix}${var.workerNameQualifier}${count.index}-key.pem"
    destination = "${var.envPrefix}${var.workerNameQualifier}${count.index}-key.pem"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "config/${var.envPrefix}${var.workerNameQualifier}${count.index}.kubeconfig"
    destination = "${var.envPrefix}${var.workerNameQualifier}${count.index}.kubeconfig"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "config/kube-proxy.kubeconfig"
    destination = "kube-proxy.kubeconfig"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "config/kube-proxy.kubeconfig"
    destination = "kube-proxy.kubeconfig"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "../config/12-get-worker-bits.sh"
    destination = "12-get-worker-bits.sh"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "../config/13-install-worker-bits.sh"
    destination = "13-install-worker-bits.sh"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "file" {
    source      = "../config/14-config-worker.sh"
    destination = "14-config-worker.sh"

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y install socat",
      "chmod +x ~/*.sh",
      "./12-get-worker-bits.sh ${var.verK8s} ${var.verContainerd} ${var.verCni}",
      "./13-install-worker-bits.sh",
      "./14-config-worker.sh ${var.envPrefix}${var.workerNameQualifier}${count.index} ${var.serviceClusterKubeDns} ${var.podSubnetCidr} ${var.podSubnetPrefix}${count.index}${var.podSubnetSuffix}"
    ]

    connection {
      type     = "ssh"
      user     = "${var.awsSshUser}"
      private_key = "${file("${var.awsSshKeyPath}/${var.awsSshKeyName}.pem")}"
    }
  }
}

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
  # need a hack to get all three - https://github.com/hashicorp/terraform/pull/9986
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

/*
resource "google_compute_route" "worker-pod-route" {
  count = "${google_compute_instance.worker-nodes.count}"

  name        = "kubernetes-route-worker-${count.index}-pods"
  dest_range  = "${var.podSubnetPrefix}${count.index}${var.podSubnetSuffix}"
  network     = "${google_compute_network.net.self_link}"
  next_hop_ip = "${var.workerPrimaryIpPrefix}${count.index}"
  priority = 1000
}
*/