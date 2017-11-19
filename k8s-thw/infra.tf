variable "env" {
  default = "siler-k8s-thw"
}

provider "google" {
  credentials = "${file("../../secrets/gcp/***REMOVED***-default/***REMOVED*** GCS 7531 ***REMOVED*** Prj Blue ***REMOVED***-437967ffb3d7.json")}"
  project     = "***REMOVED***-gcs-7531-***REMOVED***-prj-***REMOVED***-***REMOVED***"
  region      = "us-west1"
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
