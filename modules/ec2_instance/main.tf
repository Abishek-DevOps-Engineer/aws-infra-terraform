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

     tags = {
    Name = var.name
  }

provisioner "file" {
  source      = var.source_path
  destination = var.destination_path

  connection {
    type     = "ssh"
    user     = var.username
    host     = self.public_ip
    private_key = file(var.private_key_path)
  }
}

  

}

