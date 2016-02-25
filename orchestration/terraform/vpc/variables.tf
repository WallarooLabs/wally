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

