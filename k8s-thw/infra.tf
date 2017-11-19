variable "env" {
  default = "siler-k8s-thw"
}

variable "region" {
  default = "us-west1"
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

resource "google_compute_address" "api-server" {
  name = "${var.env}"
  region = "${var.region}"
}
