variable "cluster_name" {
  description = "Cluster name for cluster to manage."
  default = "sample"
}

variable "aws_key_name" {
  description = "AWS Key Pair name."
  default = "us-east-1"
}

variable "aws_iam_role" {
  description = "AWS IAM Role name."
  default = "developers"
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default = "us-east-1"
}

variable "aws_subnet_id" {
  description = "AWS subnet_id to launch servers."
  default = ""
}

variable "aws_profile" {
  description = "AWS profile to use."
  default = "default"
}

variable "aws_detailed_monitoring" {
  description = "Whether to enable AWS detailed monitoring or not."
  default = "false"
}

variable "project_tag" {
  description = "Value for the project tag."
  default = "arizona"
}

variable "placement_group" {
  description = "Whther to use Placement Groups for cluster or not."
  default = ""
}

variable "placement_tenancy" {
  description = "Whther to use dedicated hosts for cluster or not."
  default = ""
}

variable "leader_instance_type" {
  description = "Instance type for the leader nodes."
  default = "t2.nano"
}

variable "leader_default_nodes" {
  description = "Default number of leader nodes."
  default = "1"
}

variable "leader_user_data" {
  description = "user_data file for leader nodes."
  default = "leader_user_data.sh"
}

variable "leader_spot_price" {
  description = "Spot price to bid for the leader nodes."
  default = ""
}

variable "follower_instance_type" {
  description = "Instance type for the follower nodes."
  default = "t2.nano"
}

variable "follower_default_nodes" {
  description = "Default number of follower nodes."
  default = "2"
}

variable "follower_user_data" {
  description = "user_data file for follower nodes."
  default = "follower_user_data.sh"
}

variable "follower_spot_price" {
  description = "Spot price to bid for the follower nodes."
  default = ""
}

variable "instance_amis" {
  description = "AMI for all instances."
  default = {
    us-east-1 = "ami-0a1f4c1d"
  }
}

