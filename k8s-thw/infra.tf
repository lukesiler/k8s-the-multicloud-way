variable "env" {
  default = "siler-k8s-thw"
}

variable "region" {
  default = "us-west1"
}

variable "zone" {
  default = "a"
}

variable "zones" {
  default = {
    "0" = "a"
    "1" = "b"
    "2" = "c"
  }
}

variable "gcp-project" {
  default = "***REMOVED***-gcs-7531-***REMOVED***-prj-***REMOVED***-***REMOVED***"
}

variable "gcp-credential" {
  default = "../../secrets/gcp/***REMOVED***-default/***REMOVED*** GCS 7531 ***REMOVED*** Prj Blue ***REMOVED***-437967ffb3d7.json"
}

variable "cidr-nodes" {
  default = "10.240.0.0/24"
}
variable "master-node-ip-prefix" {
  default = "10.240.0.1"
}
variable "master-name-qualifier" {
  default = "-m-"
}
variable "worker-node-ip-prefix" {
  default = "10.240.0.2"
}
variable "worker-name-qualifier" {
  default = "-w-"
}

variable "cidr-pod-net" {
  default = "10.200.0.0/16"
}
variable "cidr-pods" {
  default = {
    "0" = "10.200.0.0/24"
    "1" = "10.200.1.0/24"
    "2" = "10.200.2.0/24"
  }
}

variable "cidr-service-net" {
  default = "10.32.0.0/24"
}
variable "cluster-dns" {
  default = "10.32.0.10"
}

variable "api-server-port" {
  default = "6443"
}

variable "keypairs" {
  default = {
    "ca" = "ca"
    "api" = "kubernetes"
  }
}

variable "ssh-user" {
  default = "siler"
}

variable "ssh-key-path" {
  default = "~/.ssh/google_compute_engine"
}

provider "google" {
  credentials = "${file("${var.gcp-credential}")}"
  project     = "${var.gcp-project}"
  region      = "${var.region}"
}

resource "google_compute_network" "net" {
  name                    = "${var.env}"
  auto_create_subnetworks = "false"
  description             = "Kubernetes the Hard Way - ${var.env}"
}

output "net-gtwy" {
  value = "${google_compute_network.net.gateway_ipv4}"
}

output "net-self_link" {
  value = "${google_compute_network.net.self_link}"
}

resource "google_compute_subnetwork" "subnet-nodes" {
  name          = "${var.env}-nodes"
  ip_cidr_range = "${var.cidr-nodes}"
  network       = "${google_compute_network.net.self_link}"
  region        = "${var.region}"
}

output "subnet-nodes-self_link" {
  value = "${google_compute_subnetwork.subnet-nodes.self_link}"
}

resource "google_compute_firewall" "allow-internal" {
  name    = "${var.env}-allow-internal"
  network = "${google_compute_network.net.self_link}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  source_ranges = ["${var.cidr-nodes}", "${var.cidr-pod-net}"]
}

output "allow-internal-self_link" {
  value = "${google_compute_firewall.allow-internal.self_link}"
}

resource "google_compute_firewall" "allow-external" {
  name    = "${var.env}-allow-external"
  network = "${google_compute_network.net.self_link}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports = ["22", "${var.api-server-port}"]
  }

  source_ranges = ["0.0.0.0/0"]
}

output "allow-external-self_link" {
  value = "${google_compute_firewall.allow-external.self_link}"
}

resource "google_compute_address" "api-server" {
 name = "${var.env}"
 region = "${var.region}"
}
output "api-server-self_link" {
 value = "${google_compute_address.api-server.self_link}"
}
output "api-server-address" {
 value = "${google_compute_address.api-server.address}"
}
output "api-server-curl" {
 value = "curl --cacert pki/ca.pem https://${google_compute_address.api-server.address}:${var.api-server-port}/version"
}
# mac curl has trouble with PEM format
output "convert-to-pkcs12-for-mac-curl" {
 value = "openssl pkcs12 -export -in pki/admin.pem -inkey pki/admin-key.pem -out pki/admin.p12"
}
output "curl-as-admin" {
 value = "curl --cacert pki/ca.pem --cert pki/admin.pem --key pki/admin-key.pem https://${google_compute_address.api-server.address}:${var.api-server-port}/api/v1/nodes"
}
output "create-servers" {
  value = "kubectl run whoami --replicas=3 --labels=\"run=server-example\" --image=emilevauge/whoami  --port=8081"
}

resource "null_resource" "pki-keypairs" {
  count = "1"

  provisioner "local-exec" {
    command = "cd pki;./1-gen-ca.sh"
  }
  provisioner "local-exec" {
    command = "cd pki;./2-gen-admin.sh"
  }
  provisioner "local-exec" {
    command = "cd pki;./3-gen-worker-kubelets.sh"
  }
  provisioner "local-exec" {
    command = "cd pki;./4-gen-kube-proxy.sh"
  }
  provisioner "local-exec" {
    command = "cd pki;./5-gen-kube-api-server.sh ${google_compute_address.api-server.address}"
  }
  provisioner "local-exec" {
    command = "cd pki;./6-gen-encrypt-key.sh"
  }
  provisioner "local-exec" {
    command = "cd config;./7-gen-worker-config.sh ${google_compute_address.api-server.address}"
  }
}

resource "google_compute_instance" "master-nodes" {
  count = 3
  name         = "${var.env}${var.master-name-qualifier}${count.index}"
  machine_type = "n1-standard-1"
  // future - use conditional to spread across zones by index
  zone         = "${var.region}-${var.zone}"

  tags = ["${var.env}", "master"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1604-lts"
      size = 200
    }
  }

  can_ip_forward = true

  network_interface {
    subnetwork = "${google_compute_subnetwork.subnet-nodes.self_link}"
    address = "${var.master-node-ip-prefix}${count.index}"
    access_config {
      // Ephemeral Public IP
    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  provisioner "file" {
    source      = "pki/${var.keypairs["ca"]}.pem"
    destination = "${var.keypairs["ca"]}.pem"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.keypairs["ca"]}-key.pem"
    destination = "${var.keypairs["ca"]}-key.pem"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.keypairs["api"]}.pem"
    destination = "${var.keypairs["api"]}.pem"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.keypairs["api"]}-key.pem"
    destination = "${var.keypairs["api"]}-key.pem"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "pki/encryption-config.yaml"
    destination = "encryption-config.yaml"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/8-get-master-bits.sh"
    destination = "8-get-master-bits.sh"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/9-setup-etcd.sh"
    destination = "9-setup-etcd.sh"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/10-setup-k8s-ctrl.sh"
    destination = "10-setup-k8s-ctrl.sh"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/*.sh",
      "~/8-get-master-bits.sh",
      "~/9-setup-etcd.sh ${count.index} ${var.master-node-ip-prefix} ${var.master-name-qualifier}",
      "~/10-setup-k8s-ctrl.sh ${count.index} ${var.master-node-ip-prefix} ${var.cidr-service-net} ${var.cidr-pod-net}"
    ]

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
}

resource "null_resource" "master-nodes-api-rbac" {
  # run RBAC config on just one of the masters after waiting for k8s API healthz
  count = "1"

  provisioner "file" {
    source      = "config/11-config-rbac-kubelet.sh"
    destination = "11-config-rbac-kubelet.sh"

    connection {
      // use index of the last master node for best chance that others are up and configured
      host     = "${google_compute_instance.master-nodes.2.network_interface.0.access_config.0.assigned_nat_ip}"
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/11-config-rbac-kubelet.sh",
      "~/11-config-rbac-kubelet.sh"
    ]

    connection {
      // use index of the last master node for best chance that others are up and configured
      host     = "${google_compute_instance.master-nodes.2.network_interface.0.access_config.0.assigned_nat_ip}"
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
}

resource "google_compute_instance" "worker-nodes" {
  count = 3

  name         = "${var.env}${var.worker-name-qualifier}${count.index}"
  machine_type = "n1-standard-1"
  zone         = "${var.region}-${var.zone}"

  tags = ["${var.env}", "worker"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1604-lts"
      size = 200
    }
  }

  can_ip_forward = true

  network_interface {
    subnetwork = "${google_compute_subnetwork.subnet-nodes.self_link}"
    address = "${var.worker-node-ip-prefix}${count.index}"
    access_config {
      // Ephemeral Public IP
    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata {
    pod-cidr = "${lookup(var.cidr-pods, count.index)}"
  }

  provisioner "file" {
    source      = "pki/${var.keypairs["ca"]}.pem"
    destination = "${var.keypairs["ca"]}.pem"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.env}${var.worker-name-qualifier}${count.index}.pem"
    destination = "${var.env}${var.worker-name-qualifier}${count.index}.pem"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.env}${var.worker-name-qualifier}${count.index}-key.pem"
    destination = "${var.env}${var.worker-name-qualifier}${count.index}-key.pem"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/${var.env}${var.worker-name-qualifier}${count.index}.kubeconfig"
    destination = "${var.env}${var.worker-name-qualifier}${count.index}.kubeconfig"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/kube-proxy.kubeconfig"
    destination = "kube-proxy.kubeconfig"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/kube-proxy.kubeconfig"
    destination = "kube-proxy.kubeconfig"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/12-get-worker-bits.sh"
    destination = "12-get-worker-bits.sh"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/13-install-worker-bits.sh"
    destination = "13-install-worker-bits.sh"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/14-config-worker.sh"
    destination = "14-config-worker.sh"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y install socat",
      "chmod +x ~/*.sh",
      "./12-get-worker-bits.sh",
      "./13-install-worker-bits.sh",
      "./14-config-worker.sh ${var.env}${var.worker-name-qualifier}${count.index} ${var.cluster-dns} ${var.cidr-pod-net} ${lookup(var.cidr-pods, count.index)}"
    ]

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
}

resource "google_compute_route" "worker-pod-route" {
  count = "${google_compute_instance.worker-nodes.count}"

  name        = "kubernetes-route-worker-${count.index}-pods"
  dest_range  = "${lookup(var.cidr-pods, count.index)}"
  network     = "${google_compute_network.net.self_link}"
  next_hop_ip = "${var.worker-node-ip-prefix}${count.index}"
  priority = 1000
}

resource "google_compute_target_pool" "master-node-pool" {
  name = "${var.env}-masters-pool"

  instances = [
    "${google_compute_instance.master-nodes.*.self_link}"
  ]

  // add health check in future
}

/*
resource "google_compute_http_health_check" "default" {
  name               = "default"
  request_path       = "/"
  check_interval_sec = 1
  timeout_sec        = 1
}
*/

resource "google_compute_forwarding_rule" "api-server-lb" {
  name       = "${var.env}-forwarding-rule"
  target     = "${google_compute_target_pool.master-node-pool.self_link}"
  port_range = "${var.api-server-port}"
  ip_address = "${google_compute_address.api-server.self_link}"

  provisioner "local-exec" {
    command = "cd config;./15-setup-kubectl-local.sh ${var.env} ${google_compute_address.api-server.address}"
  }
  provisioner "local-exec" {
    command = "cd config;./16-setup-dns.sh ${var.cluster-dns}"
  }
}
