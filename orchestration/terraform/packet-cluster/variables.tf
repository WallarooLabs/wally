variable "cluster_name" {
  description = "Cluster name for cluster to manage."
  default = "sample"
}

variable "packet_region" {
  description = "Packet region to launch servers. ewr1==New York, sjc1==San Jose,CA, ams1==Amsterdam"
  default = "ewr1"
}

variable "packet_api_key" {
	description = "get your packet api key at https://app.packet.net/portal#/api-keys"
    default = "bad_api_key"
}

variable "packet_project_id" {
	description = "After you create packet project, get your api key, then get your project id key via https://app.packet.net/portal#/projects/list/table "
    default = "bad_project_id"
}

variable "leader_instance_type" {
  description = "Instance type for the leader nodes. baremetal_{0-3} for Type {0-3}. See: https://www.packet.net/bare-metal/"
  default = "baremetal_0"
}

variable "leader_user_data" {
  description = "user_data file for leader nodes."
  default = "leader_user_data.sh"
}

variable "leader_default_nodes" {
  description = "Default number of leader nodes."
  default = "1"
}

variable "follower_instance_type" {
  description = "Instance type for the follower nodes. baremetal_{0-3} for Type {0-3}. See: https://www.packet.net/bare-metal/"
  default = "baremetal_0"
}

variable "follower_user_data" {
  description = "user_data file for follower nodes."
  default = "follower_user_data.sh"
}

variable "follower_default_nodes" {
  description = "Default number of follower nodes."
  default = "2"
}

variable "packet_instance_os" {
  description = "OS for all instances."
  default = "ubuntu_16_04_image"
}

variable "project_tag" {
  description = "Value for the project tag."
  default = "buffy"
}

