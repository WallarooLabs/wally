output "VPC_ID" {
  value = "${aws_vpc.default.id}"
}

output "SUBNET_ID" {
  value = "${aws_subnet.default.id}"
}

output "SECURITY_GROUP_ID" {
  value = "${aws_security_group.default.id}"
}

