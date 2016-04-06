variable "aws_region" {
  description = "AWS region to launch servers."
  default = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use."
  default = "default"
}

variable "project_tag" {
  description = "Value for the project tag."
  default = "buffy"
}

variable "aws_availability_zone_1" {
  description = "Availability zone 1"
  default = ""
}

variable "aws_availability_zone_2" {
  description = "Availability zone 2"
  default = ""
}

variable "aws_availability_zone_3" {
  description = "Availability zone 3"
  default = ""
}

variable "aws_availability_zone_4" {
  description = "Availability zone 4"
  default = ""
}

