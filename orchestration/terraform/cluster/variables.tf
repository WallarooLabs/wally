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
  default = "buffy"
}

variable "placement_group" {
  description = "Whther to use Placement Groups for cluster or not."
  default = ""
}

variable "leader_instance_type" {
  description = "Instance type for the leader nodes."
  default = "t2.nano"
}

variable "leader_max_nodes" {
  description = "Maximum number of leader nodes."
  default = "1"
}

variable "leader_min_nodes" {
  description = "Minimum number of leader nodes."
  default = "1"
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

variable "follower_max_nodes" {
  description = "Maximum number of follower nodes."
  default = "9"
}

variable "follower_min_nodes" {
  description = "Minimum number of follower nodes."
  default = "1"
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
    sa-east-1 = "ami-a9e262c5"
    us-west-1 = "ami-833c4be3"
    us-west-2 = "ami-242fcb44"
    us-east-1 = "ami-002f0f6a"
    eu-west-1 = "ami-86f743f5"
    ap-southeast-1 = "ami-8f804fec"
    ap-southeast-2 = "ami-22715541"
    eu-central-1 = "ami-60869f0c"
    ap-northeast-1 = "ami-e16c558f"
    ap-northeast-2 = "ami-232be54d"
  }
}

