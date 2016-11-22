# Shared infrastructure state stored in Atlas
data "terraform_remote_state" "vpc" {
  backend = "s3"
  "config" {
    "bucket" = "sendence-dev"
    "key" = "terraform-state/vpc/${var.aws_region}-terraform.tfstate"
    "region" = "us-east-1"
  }

}

provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

# placement groups don't work with t2.nano which is our default instance type
resource "aws_placement_group" "default" {
  name = "arizona-${var.cluster_name}"
  strategy = "cluster"

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_instance" "leaders" {
  subnet_id = "${coalesce(var.aws_subnet_id, data.terraform_remote_state.vpc.SUBNET_1_ID)}"
  count = "${var.leader_default_nodes}"

# placement groups don't work with t2.nano which is our default instance type
  placement_group = "${var.placement_group}"

  depends_on = [ "aws_placement_group.default" ]

  tags {
    Name = "${var.cluster_name}:${var.project_tag}-leader"
    Project = "${var.project_tag}"
    Role = "leader"
    ClusterName = "${var.cluster_name}"
  }

  lifecycle {
    create_before_destroy = true
  }

  ami = "${var.instance_ami}"
  instance_type = "${var.leader_instance_type}"
  iam_instance_profile = "${var.aws_iam_role}"
  monitoring = "${var.aws_detailed_monitoring}"
  key_name = "${var.aws_key_name}"
  security_groups = [ "${data.terraform_remote_state.vpc.SECURITY_GROUP_ID}" ]
  user_data = "${file("${var.leader_user_data}")}"
  tenancy = "${var.placement_tenancy}"

  root_block_device {
    volume_type  = "standard"
  }

}

resource "aws_instance" "followers" {
  subnet_id = "${coalesce(var.aws_subnet_id, data.terraform_remote_state.vpc.SUBNET_1_ID)}"
  count = "${var.follower_default_nodes}"

# placement groups don't work with t2.nano which is our default instance type
  placement_group = "${var.placement_group}"

  depends_on = [ "aws_placement_group.default" ]

  tags {
    Name = "${var.cluster_name}:${var.project_tag}-follower"
    Project = "${var.project_tag}"
    Role = "follower"
    ClusterName = "${var.cluster_name}"
  }

  lifecycle {
    create_before_destroy = true
  }

  ami = "${var.instance_ami}"
  instance_type = "${var.follower_instance_type}"
  iam_instance_profile = "${var.aws_iam_role}"
  monitoring = "${var.aws_detailed_monitoring}"
  key_name = "${var.aws_key_name}"
  security_groups = [ "${data.terraform_remote_state.vpc.SECURITY_GROUP_ID}" ]
  user_data = "${file("${var.follower_user_data}")}"
  tenancy = "${var.placement_tenancy}"

  root_block_device {
    volume_type  = "standard"
  }

}



