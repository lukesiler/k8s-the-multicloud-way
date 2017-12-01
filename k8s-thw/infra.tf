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

  source_ranges = ["10.240.0.0/24", "10.200.0.0/16"]
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

//resource "google_compute_address" "api-server" {
//  name = "${var.env}"
//  region = "${var.region}"
//}
//output "api-server-self_link" {
//  value = "${google_compute_address.api-server.self_link}"
//}
//output "api-server-address" {
//  value = "${google_compute_address.api-server.address}"
//}

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
    address = "10.240.0.1${count.index}"
    access_config {
      // Ephemeral Public IP
    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
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
    address = "10.240.0.2${count.index}"
    access_config {
      // Ephemeral Public IP
    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata {
    pod-cidr = "10.200.${count.index}.0/24"
  }
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

resource "google_compute_forwarding_rule" "default" {
  name       = "${var.env}-forwarding-rule"
  target     = "${google_compute_target_pool.master-node-pool.self_link}"
  port_range = "6443"
}
