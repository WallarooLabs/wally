# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags {
    Project = "${var.project_tag}"
    Name = "${var.project_tag}-vpc"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
  tags {
    Project = "${var.project_tag}"
    Name = "${var.project_tag}-gateway"
  }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default-1" {
  availability_zone       = "${var.aws_availability_zone_1}"
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.0.0/19"
  map_public_ip_on_launch = true
  tags {
    Project = "${var.project_tag}"
    Name = "${var.project_tag}-subnet-1"
  }
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default-2" {
  availability_zone       = "${var.aws_availability_zone_2}"
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.32.0/19"
  map_public_ip_on_launch = true
  tags {
    Project = "${var.project_tag}"
    Name = "${var.project_tag}-subnet-2"
  }
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default-3" {
  availability_zone       = "${var.aws_availability_zone_3}"
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.64.0/19"
  map_public_ip_on_launch = true
  tags {
    Project = "${var.project_tag}"
    Name = "${var.project_tag}-subnet-3"
  }
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default-4" {
  availability_zone       = "${var.aws_availability_zone_4}"
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.96.0/19"
  map_public_ip_on_launch = true
  tags {
    Project = "${var.project_tag}"
    Name = "${var.project_tag}-subnet-4"
  }
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "tf_default"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # full access from the internet
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Project = "${var.project_tag}"
    Name = "${var.project_tag}-securitygroup"
  }
}


