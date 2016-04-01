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

variable "instance_ami" {
  description = "AMI for all instances."
  default = "ami-002f0f6a"
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

