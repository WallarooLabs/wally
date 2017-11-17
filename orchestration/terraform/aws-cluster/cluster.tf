# Shared infrastructure state stored in Atlas
data "terraform_remote_state" "vpc" {
  backend = "s3"
  "config" {
    "bucket" = "${var.terraform_state_aws_bucket}"
    "key" = "terraform-state/vpc/${var.aws_region}-terraform.tfstate"
    "region" = "${var.terraform_state_aws_region}"
  }

}

provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

# placement groups don't work with t2.nano which is our default instance type
resource "aws_placement_group" "default" {
  name = "wallaroo-${var.cluster_name}"
  strategy = "cluster"

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "leaders" {
  name = "${var.cluster_name}_leader-asg"
  vpc_zone_identifier = [ "${coalesce(var.aws_subnet_id, data.terraform_remote_state.vpc.SUBNET_1_ID)}" ]
  max_size = "${var.leader_max_nodes}"
  min_size = "${var.leader_min_nodes}"
  desired_capacity = "${var.leader_default_nodes}"
  force_delete = true
  launch_configuration = "${aws_launch_configuration.leader_launch_config.name}"

# placement groups don't work with t2.nano which is our default instance type
  placement_group = "${var.placement_group}"

  depends_on = [ "aws_placement_group.default" ]

  tag {
    key = "Name"
    value = "${var.cluster_name}:${var.project_tag}-leader"
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

  tag {
    key = "ClusterName"
    value = "${var.cluster_name}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "followers" {
  name = "${var.cluster_name}_follower-asg"
  vpc_zone_identifier = [ "${coalesce(var.aws_subnet_id, data.terraform_remote_state.vpc.SUBNET_1_ID)}" ]
  max_size = "${var.follower_max_nodes}"
  min_size = "${var.follower_min_nodes}"
  desired_capacity = "${var.follower_default_nodes}"
  force_delete = true
  launch_configuration = "${aws_launch_configuration.follower_launch_config.name}"

# placement groups don't work with t2.nano which is our default instance type
  placement_group = "${var.placement_group}"

  depends_on = [ "aws_placement_group.default" ]

  tag {
    key = "Name"
    value = "${var.cluster_name}:${var.project_tag}-follower"
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

  tag {
    key = "ClusterName"
    value = "${var.cluster_name}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

}


resource "aws_launch_configuration" "follower_launch_config" {
  name = "${var.cluster_name}_follower-launch-config"
  image_id = "${lookup(var.instance_amis, var.aws_region)}"
  instance_type = "${var.follower_instance_type}"
  spot_price = "${var.follower_spot_price}"
  iam_instance_profile = "${var.aws_iam_role}"
  enable_monitoring = "${var.aws_detailed_monitoring}"
  key_name = "${var.aws_key_name}"
  security_groups = [ "${data.terraform_remote_state.vpc.SECURITY_GROUP_ID}" ]
  user_data = "${file("${var.follower_user_data}")}"
  placement_tenancy = "${var.placement_tenancy}"

  root_block_device {
    volume_size = "${var.instance_volume_size}"
  }

  ephemeral_block_device {
    device_name = "xvdb"
    virtual_name = "ephemeral0"
  }
  ephemeral_block_device {
    device_name = "xvdc"
    virtual_name = "ephemeral1"
  }
  ephemeral_block_device {
    device_name = "xvdd"
    virtual_name = "ephemeral2"
  }
  ephemeral_block_device {
    device_name = "xvde"
    virtual_name = "ephemeral3"
  }
  ephemeral_block_device {
    device_name = "xvdf"
    virtual_name = "ephemeral4"
  }
  ephemeral_block_device {
    device_name = "xvdg"
    virtual_name = "ephemeral5"
  }
  ephemeral_block_device {
    device_name = "xvdh"
    virtual_name = "ephemeral6"
  }
  ephemeral_block_device {
    device_name = "xvdi"
    virtual_name = "ephemeral7"
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_launch_configuration" "leader_launch_config" {
  name = "${var.cluster_name}_leader-launch-config"
  image_id = "${lookup(var.instance_amis, var.aws_region)}"
  instance_type = "${var.leader_instance_type}"
  spot_price = "${var.leader_spot_price}"
  iam_instance_profile = "${var.aws_iam_role}"
  enable_monitoring = "${var.aws_detailed_monitoring}"
  key_name = "${var.aws_key_name}"
  security_groups = [ "${data.terraform_remote_state.vpc.SECURITY_GROUP_ID}" ]
  user_data = "${file("${var.leader_user_data}")}"
  placement_tenancy = "${var.placement_tenancy}"

  root_block_device {
    volume_size = "${var.instance_volume_size}"
  }

  ephemeral_block_device {
    device_name = "xvdb"
    virtual_name = "ephemeral0"
  }
  ephemeral_block_device {
    device_name = "xvdc"
    virtual_name = "ephemeral1"
  }
  ephemeral_block_device {
    device_name = "xvdd"
    virtual_name = "ephemeral2"
  }
  ephemeral_block_device {
    device_name = "xvde"
    virtual_name = "ephemeral3"
  }
  ephemeral_block_device {
    device_name = "xvdf"
    virtual_name = "ephemeral4"
  }
  ephemeral_block_device {
    device_name = "xvdg"
    virtual_name = "ephemeral5"
  }
  ephemeral_block_device {
    device_name = "xvdh"
    virtual_name = "ephemeral6"
  }
  ephemeral_block_device {
    device_name = "xvdi"
    virtual_name = "ephemeral7"
  }

  lifecycle {
    create_before_destroy = true
  }

}


