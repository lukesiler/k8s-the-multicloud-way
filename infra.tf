variable "cloudRegion" {
  default = "us-west1"
}

variable "cloudZone" {
  default = "a"
}

variable "cloudProject" {
  default = "***REMOVED***-gcs-7531-***REMOVED***-prj-***REMOVED***-***REMOVED***"
}

variable "cloudCredential" {
  default = "../../secrets/gcp/***REMOVED***-default/***REMOVED*** GCS 7531 ***REMOVED*** Prj Blue ***REMOVED***-437967ffb3d7.json"
}

variable "envPrefix" {
  default = "siler-k8s-thw"
}
variable "envName" {
  default = "Kubernetes The Hard Way"
}

variable "physicalSubnetCidr" {
  default = "10.240.0.0/24"
}
variable "masterPrimaryIpPrefix" {
  default = "10.240.0.1"
}
variable "workerPrimaryIpPrefix" {
  default = "10.240.0.2"
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

variable "ssh-user" {
  default = "siler"
}

variable "ssh-key-path" {
  default = "~/.ssh/google_compute_engine"
}

provider "google" {
  credentials = "${file("${var.cloudCredential}")}"
  project     = "${var.cloudProject}"
  region      = "${var.cloudRegion}"
}

resource "google_compute_network" "net" {
  name                    = "${var.envPrefix}"
  auto_create_subnetworks = "false"
  description             = "${var.envName} - ${var.envPrefix}"
}

output "net-gtwy" {
  value = "${google_compute_network.net.gateway_ipv4}"
}

output "net-self_link" {
  value = "${google_compute_network.net.self_link}"
}

resource "google_compute_subnetwork" "subnet-nodes" {
  name          = "${var.envPrefix}-nodes"
  ip_cidr_range = "${var.physicalSubnetCidr}"
  network       = "${google_compute_network.net.self_link}"
  region        = "${var.cloudRegion}"
}

output "subnet-nodes-self_link" {
  value = "${google_compute_subnetwork.subnet-nodes.self_link}"
}

resource "google_compute_firewall" "allow-internal" {
  name    = "${var.envPrefix}-allow-internal"
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

  source_ranges = ["${var.physicalSubnetCidr}", "${var.podSubnetCidr}"]
}

output "allow-internal-self_link" {
  value = "${google_compute_firewall.allow-internal.self_link}"
}

resource "google_compute_firewall" "allow-external" {
  name    = "${var.envPrefix}-allow-external"
  network = "${google_compute_network.net.self_link}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports = ["22", "${var.masterApiServerPort}"]
  }

  source_ranges = ["0.0.0.0/0"]
}

output "allow-external-self_link" {
  value = "${google_compute_firewall.allow-external.self_link}"
}

resource "google_compute_address" "api-server" {
 name = "${var.envPrefix}"
 region = "${var.cloudRegion}"
}
output "api-server-self_link" {
 value = "${google_compute_address.api-server.self_link}"
}
output "api-server-address" {
 value = "${google_compute_address.api-server.address}"
}
output "api-server-curl" {
 value = "curl --cacert pki/ca.pem https://${google_compute_address.api-server.address}:${var.masterApiServerPort}/version"
}
# mac curl has trouble with PEM format
output "convert-to-pkcs12-for-mac-curl" {
 value = "openssl pkcs12 -export -in pki/admin.pem -inkey pki/admin-key.pem -out pki/admin.p12"
}
output "curl-as-admin" {
 value = "curl --cacert pki/ca.pem --cert pki/admin.pem --key pki/admin-key.pem https://${google_compute_address.api-server.address}:${var.masterApiServerPort}/api/v1/nodes"
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
  name         = "${var.envPrefix}${var.masterNameQualifier}${count.index}"
  machine_type = "n1-standard-1"
  // future - use conditional to spread across zones by index
  zone         = "${var.cloudRegion}-${var.cloudZone}"

  tags = ["${var.envPrefix}", "master"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1604-lts"
      size = 200
    }
  }

  can_ip_forward = true

  network_interface {
    subnetwork = "${google_compute_subnetwork.subnet-nodes.self_link}"
    address = "${var.masterPrimaryIpPrefix}${count.index}"
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
      "~/8-get-master-bits.sh ${var.verEtcd} ${var.verK8s}",
      "~/9-setup-etcd.sh ${count.index} ${var.masterPrimaryIpPrefix} ${var.masterNameQualifier}",
      "~/10-setup-k8s-ctrl.sh ${count.index} ${var.masterPrimaryIpPrefix} ${var.serviceSubnetCidr} ${var.podSubnetCidr}"
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

  name         = "${var.envPrefix}${var.workerNameQualifier}${count.index}"
  machine_type = "n1-standard-1"
  zone         = "${var.cloudRegion}-${var.cloudZone}"

  tags = ["${var.envPrefix}", "worker"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1604-lts"
      size = 200
    }
  }

  can_ip_forward = true

  network_interface {
    subnetwork = "${google_compute_subnetwork.subnet-nodes.self_link}"
    address = "${var.workerPrimaryIpPrefix}${count.index}"
    access_config {
      // Ephemeral Public IP
    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata {
    pod-cidr = "${var.podSubnetPrefix}${count.index}${var.podSubnetSuffix}"
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
    source      = "pki/${var.envPrefix}${var.workerNameQualifier}${count.index}.pem"
    destination = "${var.envPrefix}${var.workerNameQualifier}${count.index}.pem"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "pki/${var.envPrefix}${var.workerNameQualifier}${count.index}-key.pem"
    destination = "${var.envPrefix}${var.workerNameQualifier}${count.index}-key.pem"

    connection {
      type     = "ssh"
      user     = "${var.ssh-user}"
      private_key = "${file("${var.ssh-key-path}")}"
    }
  }
  provisioner "file" {
    source      = "config/${var.envPrefix}${var.workerNameQualifier}${count.index}.kubeconfig"
    destination = "${var.envPrefix}${var.workerNameQualifier}${count.index}.kubeconfig"

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
      "./12-get-worker-bits.sh ${var.verK8s} ${var.verContainerd} ${var.verCni}",
      "./13-install-worker-bits.sh",
      "./14-config-worker.sh ${var.envPrefix}${var.workerNameQualifier}${count.index} ${var.serviceClusterKubeDns} ${var.podSubnetCidr} ${var.podSubnetPrefix}${count.index}${var.podSubnetSuffix}"
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
  dest_range  = "${var.podSubnetPrefix}${count.index}${var.podSubnetSuffix}"
  network     = "${google_compute_network.net.self_link}"
  next_hop_ip = "${var.workerPrimaryIpPrefix}${count.index}"
  priority = 1000
}

resource "google_compute_target_pool" "master-node-pool" {
  name = "${var.envPrefix}-masters-pool"

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
  name       = "${var.envPrefix}-forwarding-rule"
  target     = "${google_compute_target_pool.master-node-pool.self_link}"
  port_range = "${var.masterApiServerPort}"
  ip_address = "${google_compute_address.api-server.self_link}"

  provisioner "local-exec" {
    command = "cd config;./15-setup-kubectl-local.sh ${var.envPrefix} ${google_compute_address.api-server.address}"
  }
  provisioner "local-exec" {
    command = "cd config;./16-setup-dns.sh ${var.serviceClusterKubeDns}"
  }
}
