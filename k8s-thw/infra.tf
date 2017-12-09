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

variable "cidr-nodes" {
  default = "10.240.0.0/24"
}
variable "master-node-ip-prefix" {
  default = "10.240.0.1"
}
variable "worker-node-ip-prefix" {
  default = "10.240.0.2"
}

variable "cidr-pods" {
  default = {
    "0" = "10.200.0.0/24"
    "1" = "10.200.1.0/24"
    "2" = "10.200.2.0/24"
  }
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
  credentials = "${file("../../secrets/gcp/***REMOVED***-default/***REMOVED*** GCS 7531 ***REMOVED*** Prj Blue ***REMOVED***-437967ffb3d7.json")}"
  project     = "***REMOVED***-gcs-7531-***REMOVED***-prj-***REMOVED***-***REMOVED***"
  region      = "${var.region}"
}

resource "google_compute_network" "net" {
  name                    = "${var.env}"
  auto_create_subnetworks = "false"
  description             = "Luke's Kubernetes the Hard Way, v1"
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

  source_ranges = ["${var.cidr-nodes}", "10.200.0.0/16"]
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
    ports = ["22", "6443"]
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
 value = "curl --cacert pki/ca.pem https://${google_compute_address.api-server.address}:6443/version"
}
# mac curl has trouble with PEM format
output "convert-to-pkcs12-for-mac-curl" {
 value = "openssl pkcs12 -export -in pki/admin.pem -inkey pki/admin-key.pem -out pki/admin.p12"
}
output "curl-as-admin" {
 value = "curl --cacert pki/ca.pem -E pki/admin.p12:none https://${google_compute_address.api-server.address}:6443/api/v1/nodes"
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
    command = "cd pki;./8-gen-encrypt-key.sh"
  }
  provisioner "local-exec" {
    command = "cd config;./10-gen-config.sh ${google_compute_address.api-server.address}"
  }
}

resource "google_compute_instance" "master-nodes" {
  count = 3
  name         = "${var.env}-m-${count.index}"
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
    source      = "config/12-get-master-bits.sh"
    destination = "12-get-master-bits.sh"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/13-setup-etcd.sh"
    destination = "13-setup-etcd.sh"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/14-setup-k8s-ctrl.sh"
    destination = "14-setup-k8s-ctrl.sh"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/*.sh",
      "~/12-get-master-bits.sh",
      "~/13-setup-etcd.sh",
      "~/14-setup-k8s-ctrl.sh"
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
    source      = "config/15-config-rbac-kubelet.sh"
    destination = "15-config-rbac-kubelet.sh"

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
      "chmod +x ~/15-config-rbac-kubelet.sh",
      "~/15-config-rbac-kubelet.sh"
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

  name         = "${var.env}-w-${count.index}"
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
    source      = "pki/${var.env}-w-${count.index}.pem"
    destination = "${var.env}-w-${count.index}.pem"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.env}-w-${count.index}-key.pem"
    destination = "${var.env}-w-${count.index}-key.pem"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/${var.env}-w-${count.index}.kubeconfig"
    destination = "${var.env}-w-${count.index}.kubeconfig"

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
    source      = "config/16-get-worker-bits.sh"
    destination = "16-get-worker-bits.sh"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/17-install-worker-bits.sh"
    destination = "17-install-worker-bits.sh"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/18-config-worker.sh"
    destination = "18-config-worker.sh"

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
      "./16-get-worker-bits.sh",
      "./17-install-worker-bits.sh",
      "./18-config-worker.sh"
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
  port_range = "6443"
  ip_address = "${google_compute_address.api-server.self_link}"

  provisioner "local-exec" {
    command = "cd config;./19-setup-kubectl-local.sh"
  }
  provisioner "local-exec" {
    command = "cd config;./20-setup-dns.sh"
  }
}
