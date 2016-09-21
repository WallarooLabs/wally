# Configure the Packet Provider
provider "packet" {
        auth_token = "${var.packet_api_key}"
}

resource "packet_device" "leaders" {
  hostname = "${format("${var.cluster_name}.buffy-leader-%01d", count.index+1)}"
  operating_system = "${var.packet_instance_os}"
  plan = "${var.leader_instance_type}"
  user_data = "${file("${var.leader_user_data}")}"
  facility = "${var.packet_region}"
  count = "${var.leader_default_nodes}"
  project_id    = "${var.packet_project_id}"
  billing_cycle = "hourly"

  tags = [ "${var.project_tag}", "Cluster_${var.cluster_name}", "Role_leader" ]
}

resource "packet_device" "followers" {
  hostname = "${format("${var.cluster_name}.buffy-follower-%01d", count.index+1)}"
  operating_system = "${var.packet_instance_os}"
  plan = "${var.follower_instance_type}"
  user_data = "${file("${var.follower_user_data}")}"
  facility = "${var.packet_region}"
  count = "${var.follower_default_nodes}"
  project_id    = "${var.packet_project_id}"
  billing_cycle = "hourly"

  tags = [ "${var.project_tag}", "Cluster_${var.cluster_name}", "Role_follower" ]
}

