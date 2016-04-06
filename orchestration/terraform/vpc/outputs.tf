output "VPC_ID" {
  value = "${aws_vpc.default.id}"
}

output "SUBNET_1_ID" {
  value = "${aws_subnet.default-1.id}"
}

output "SUBNET_2_ID" {
  value = "${aws_subnet.default-2.id}"
}

output "SUBNET_3_ID" {
  value = "${aws_subnet.default-3.id}"
}

output "SUBNET_4_ID" {
  value = "${aws_subnet.default-4.id}"
}

output "SECURITY_GROUP_ID" {
  value = "${aws_security_group.default.id}"
}

