provider "aws" {

    region = "ap-south-1"
  
}


#Iam role 
resource "aws_iam_role" "iam_role_awssecretsAccess" {
  name = "jenkins_awssecretsaccess"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

}
#iam policy for jenkins secrets access
resource "aws_iam_role_policy" "jenkinsawssecretsaccess_policy" {
  name = "jenkinssecretsaccess_policy"
  role = aws_iam_role.iam_role_awssecretsAccess.id


  policy = jsonencode({
	Version: "2012-10-17",
	Statement: [
		{
			Effect: "Allow",
			Action: [
				"secretsmanager:ListSecrets",
				"secretsmanager:GetSecretValue"
			],
			Resource: "*"
		}
	]
})
}
#iam instance profile to attach the iam role to ec2 instance
resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins_awssecretsaccess"
  role = aws_iam_role.iam_role_awssecretsAccess.name
}


#Jenkins Master
module "ec2_instance_jenkins_master" {

    source = "./modules/ec2_instance"
    instance_type = "t3.micro"
    ami = "ami-01a00762f46d584a1"
    key_name = "oldawskey"
    name = "Jenkins Master"
    security_groups = [aws_security_group.Jenkins_master.id]
    username = "ubuntu"
    source_path = "./jenkinssetup.sh"
    destination_path = "/home/ubuntu/jenkinssetup.sh"
    private_key_path = "/home/abishek/Abishekdir/devops/awssshkey/oldaws/oldawskey.pem"
    iam_instance_profile = aws_iam_instance_profile.jenkins_profile.name
  
}


resource "aws_security_group" "Jenkins_master" {
  name        = "jenkins_master_sg"
  description = "Allow jenkins ui access and ssh access"


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


#Jenkins Slave

module "ec2_instance_jenkinsslave" {

    source = "./modules/ec2_instance"
    instance_type = "m7i-flex.large"
    ami = "ami-01a00762f46d584a1"
    key_name = "oldawskey"
    name = "Jenkins Node"
    security_groups = [aws_security_group.Jenkins_slave.id]
    username = "ubuntu"
    source_path = "./dockersetup.sh"
    destination_path = "/home/ubuntu/dockersetup.sh"
    private_key_path = "/home/abishek/Abishekdir/devops/awssshkey/oldaws/oldawskey.pem"
  
}


resource "aws_security_group" "Jenkins_slave" {
  name        = "jenkins_slave_sg"
  description = "Allow jenkins master to access node via ssh"


  tags = {
    Name = "jenkins_slave"
  }
}
#allow ssh to jenkins slave machine
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_jenkinsslave" {
  security_group_id = aws_security_group.Jenkins_slave.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
#allow ssh to jenkins slave from master
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_jenkinsslavefrommaster" {
  security_group_id = aws_security_group.Jenkins_slave.id
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  referenced_security_group_id = aws_security_group.Jenkins_master.id
}


resource "aws_vpc_security_group_egress_rule" "jenkins_slave_allowall_outbound" {
  security_group_id = aws_security_group.Jenkins_slave.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#Jenkins slave instance 2

module "ec2_instance_jenkinsslaveprod" {

    source = "./modules/ec2_instance"
    instance_type = "m7i-flex.large"
    ami = "ami-01a00762f46d584a1"
    key_name = "oldawskey"
    name = "Jenkins Node Prod"
    security_groups = [aws_security_group.Jenkins_slave_prodinstance.id]
    username = "ubuntu"
    source_path = "./dockersetup.sh"
    destination_path = "/home/ubuntu/dockersetup.sh"
    private_key_path = "/home/abishek/Abishekdir/devops/awssshkey/oldaws/oldawskey.pem"
  
}


resource "aws_security_group" "Jenkins_slave_prodinstance" {
  name        = "jenkins_slave_prod_sg"
  description = "Allow jenkins master to access node via ssh"



  tags = {
    Name = "jenkins_slave_prod"
  }
}
#allow ssh to jenkins slave machine
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_jenkinsslave_prodinstance" {
  security_group_id = aws_security_group.Jenkins_slave_prodinstance.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
#allow ssh to jenkins slave from master
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_jenkinsmaster_to_prodinstance" {
  security_group_id = aws_security_group.Jenkins_slave_prodinstance.id
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  referenced_security_group_id = aws_security_group.Jenkins_master.id
}

#allow ssh to jenkins slave machine
resource "aws_vpc_security_group_ingress_rule" "allow_flaskappui_access" {
  security_group_id = aws_security_group.Jenkins_slave_prodinstance.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 5000
  ip_protocol       = "tcp"
  to_port           = 5000
}

#Allow Prometheus UI access
resource "aws_vpc_security_group_ingress_rule" "allow_prometheusui_access" {
  security_group_id = aws_security_group.Jenkins_slave_prodinstance.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 9090
  ip_protocol       = "tcp"
  to_port           = 9090
}

#Allow Grafana UI access
resource "aws_vpc_security_group_ingress_rule" "allow_grafanaui_access" {
  security_group_id = aws_security_group.Jenkins_slave_prodinstance.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 3000
  ip_protocol       = "tcp"
  to_port           = 3000
}

#Allow Node exporter UI access
resource "aws_vpc_security_group_ingress_rule" "allow_nodeexporterui_access" {
  security_group_id = aws_security_group.Jenkins_slave_prodinstance.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 9100
  ip_protocol       = "tcp"
  to_port           = 9100
}

resource "aws_vpc_security_group_egress_rule" "jenkins_slave2_allowall_outbound" {
  security_group_id = aws_security_group.Jenkins_slave_prodinstance.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}






