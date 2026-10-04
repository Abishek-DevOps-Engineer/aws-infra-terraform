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
    vpc_security_group_ids = var.security_groups
    iam_instance_profile = var.iam_instance_profile
    subnet_id = var.subnet_id
    user_data_base64 = var.user_data_base64

     tags = {
    Name = var.name
  }

  

}

output "instance_id" {
  value = aws_instance.this.id   # to use the resource id in the root main.tf
}

