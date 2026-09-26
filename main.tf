provider "aws" {

    region = "ap-south-1"
  
}


module "ec2_instance" {

    source = "./modules/ec2_instance"
    instance_type = "t3.micro"
    ami = "ami-01a00762f46d584a1"
    key_name = "oldawskey"
    name = "Jenkins Master"
    security_groups = [aws_security_group.Jenkins_master.id]
  
}


resource "aws_security_group" "Jenkins_master" {
  name        = "all"
  description = "Allow TLS inbound traffic and all outbound traffic"


  tags = {
    Name = "jenkins_master"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_jenkinsmaster" {
  security_group_id = aws_security_group.Jenkins_master.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "access_jenkins_ui" {
  security_group_id = aws_security_group.Jenkins_master.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}


resource "aws_vpc_security_group_egress_rule" "jenkins_master_allowall_outbound" {
  security_group_id = aws_security_group.Jenkins_master.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}



