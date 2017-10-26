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
  default = "wallaroo"
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

variable "leader_max_nodes" {
  description = "Maximum number of leader nodes."
  default = "100"
}

variable "leader_min_nodes" {
  description = "Minimum number of leader nodes."
  default = "0"
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
  default = "100"
}

variable "follower_min_nodes" {
  description = "Minimum number of follower nodes."
  default = "0"
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

variable "instance_volume_size" {
  description = "Root volume size for all nodes."
  default = "32"
}

variable "instance_amis" {
  description = "AMI for all instances."
  default = {
    sa-east-1 = "ami-1ca7d970"
    us-west-1 = "ami-1b17257b"
    us-west-2 = "ami-19e92861"
    us-east-1 = "ami-bcdc16c6"
    eu-west-1 = "ami-1b17257b"
    ap-southeast-1 = "ami-d9dca7ba"
    ap-southeast-2 = "ami-02ad4060"
    eu-central-1 = "ami-e613ac89"
    ap-northeast-1 = "ami-6959870f"
    ap-south-1 = "ami-50591a3f"
  }
}

