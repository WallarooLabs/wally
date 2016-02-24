# Shared infrastructure state stored in Atlas
resource "terraform_remote_state" "vpc" {
  backend = "s3"
  "config" {
    "bucket" = "sendence-dev"
    "key" = "terraform-state/vpc/terraform.tfstate"
    "region" = "us-east-1"
  }

  lifecycle {
    create_before_destroy = true
  }

}

provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

resource "aws_placement_group" "default" {
  name = "${var.project_tag}-default"
  strategy = "cluster"

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "leaders" {
  vpc_zone_identifier = [ "${terraform_remote_state.vpc.output.SUBNET_ID}" ]
  name = "leaders"
  max_size = "${var.leader_max_nodes}"
  min_size = "${var.leader_min_nodes}"
  desired_capacity = "${var.leader_default_nodes}"
  force_delete = true
  launch_configuration = "${aws_launch_configuration.leader_launch_config.name}"

# placement groups don't work with t2.nano which is our default instance type
#  placement_group = "${aws_placement_group.default.id}"

  tag {
    key = "Name"
    value = "${var.project_tag}-leader"
    propagate_at_launch = true
  }

  tag {
    key = "Project"
    value = "${var.project_tag}"
    propagate_at_launch = true
  }

  tag {
    key = "Role"
    value = "leader"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "followers" {
  vpc_zone_identifier = [ "${terraform_remote_state.vpc.output.SUBNET_ID}" ]
  name = "followers"
  max_size = "${var.follower_max_nodes}"
  min_size = "${var.follower_min_nodes}"
  desired_capacity = "${var.follower_default_nodes}"
  force_delete = true
  launch_configuration = "${aws_launch_configuration.follower_launch_config.name}"

# placement groups don't work with t2.nano which is our default instance type
#  placement_group = "${aws_placement_group.default.id}"

  tag {
    key = "Name"
    value = "${var.project_tag}-follower"
    propagate_at_launch = true
  }

  tag {
    key = "Project"
    value = "${var.project_tag}"
    propagate_at_launch = true
  }

  tag {
    key = "Role"
    value = "follower"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

}


resource "aws_launch_configuration" "follower_launch_config" {
  name_prefix = "follower-launch-config-"
  image_id = "${var.instance_ami}"
  instance_type = "${var.follower_instance_type}"
  iam_instance_profile = "${var.aws_iam_role}"
  key_name = "${var.aws_key_name}"
  security_groups = [ "${terraform_remote_state.vpc.output.SECURITY_GROUP_ID}" ]
  user_data = "${file("${var.follower_user_data}")}"

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_launch_configuration" "leader_launch_config" {
  name_prefix = "leader-launch-config-"
  image_id = "${var.instance_ami}"
  instance_type = "${var.leader_instance_type}"
  iam_instance_profile = "${var.aws_iam_role}"
  key_name = "${var.aws_key_name}"
  security_groups = [ "${terraform_remote_state.vpc.output.SECURITY_GROUP_ID}" ]
  user_data = "${file("${var.leader_user_data}")}"

  lifecycle {
    create_before_destroy = true
  }

}


