variable "env_name" {
  default = "siler-tf-consul"
}

variable "region" {
  default = "us-west-2"
}

variable "access_key" {}
variable "secret_key" {}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_vpc" "siler-tf-consul" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags {
    Name = "${var.env_name}"
  }
}

resource "aws_subnet" "siler-tf-consul-a" {
  vpc_id     = "${aws_vpc.siler-tf-consul.id}"
  cidr_block = "10.0.0.0/24"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true

  tags {
    Name = "${var.env_name}"
  }
}

resource "aws_subnet" "siler-tf-consul-b" {
  vpc_id     = "${aws_vpc.siler-tf-consul.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = true

  tags {
    Name = "${var.env_name}"
  }
}

resource "aws_subnet" "siler-tf-consul-c" {
  vpc_id     = "${aws_vpc.siler-tf-consul.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "${var.region}c"
  map_public_ip_on_launch = true

  tags {
    Name = "${var.env_name}"
  }
}

module "consul" {
  source = "github.com/hashicorp/consul/terraform/aws"

  vpc_id  = "${aws_vpc.siler-tf-consul.id}"
  subnets = {
    "0" = "${aws_subnet.siler-tf-consul-a.id}"
    "1" = "${aws_subnet.siler-tf-consul-b.id}"
    "2" = "${aws_subnet.siler-tf-consul-c.id}"
  }
  key_name = "siler-play"
  key_path = "../../../../secrets/aws/***REMOVED***@***REMOVED***.com/siler-play.pem"
  region  = "${var.region}"
  servers = "3"
}
