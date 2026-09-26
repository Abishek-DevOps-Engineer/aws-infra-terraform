terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}


resource "aws_instance" "this" {
    ami = var.ami
    instance_type = var.instance_type
    key_name = var.key_name
    security_groups = var.security_groups

     tags = {
    Name = var.name
  }

}

