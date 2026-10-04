provider "aws" {

  region = "ap-south-1"

}



#aws vpc
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
}

#public subnets

#Subnet1
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Subnet1"
  }
}

#Subnet2
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Subnet2"
  }
}



#route table
resource "aws_route_table" "myroutetable" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "myinternetgw"
  }
}

#Subnet1 association
resource "aws_route_table_association" "subnet1association" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.myroutetable.id
}

#Subnet2 association
resource "aws_route_table_association" "subnet2association" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.myroutetable.id
}

#internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "main"
  }
}


#private subnets
#Subnet3
resource "aws_subnet" "subnet3" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Subnet3"
  }
}

#Subnet4
resource "aws_subnet" "subnet4" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Subnet4"
  }
}

#elastic ip
resource "aws_eip" "eip" {
  domain = "vpc"
}

#nat gateway
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.subnet1.id

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

#route table
resource "aws_route_table" "myroutetablenatgw" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "mynatgw"
  }
}

#Subnet3 association
resource "aws_route_table_association" "subnet3association" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.myroutetablenatgw.id
}

#Subnet4 association
resource "aws_route_table_association" "subnet4association" {
  subnet_id      = aws_subnet.subnet4.id
  route_table_id = aws_route_table.myroutetablenatgw.id
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
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "secretsmanager:ListSecrets",
          "secretsmanager:GetSecretValue"
        ],
        Resource : "*"
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

  source               = "./modules/ec2_instance"
  instance_type        = "t3.micro"
  ami                  = "ami-01a00762f46d584a1"
  key_name             = "oldawskey"
  name                 = "Jenkins Master"
  security_groups      = [aws_security_group.Jenkins_master.id]
  iam_instance_profile = aws_iam_instance_profile.jenkins_profile.name
  subnet_id            = aws_subnet.subnet1.id
  user_data_base64     = base64encode(file("jenkinssetup.sh"))

}


resource "aws_security_group" "Jenkins_master" {
  name        = "jenkins_master_sg"
  description = "Allow jenkins ui access and ssh access"
  vpc_id      = aws_vpc.myvpc.id


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

  source           = "./modules/ec2_instance"
  instance_type    = "m7i-flex.large"
  ami              = "ami-01a00762f46d584a1"
  key_name         = "oldawskey"
  name             = "Jenkins Node"
  security_groups  = [aws_security_group.Jenkins_slave.id]
  subnet_id        = aws_subnet.subnet1.id
  user_data_base64 = base64encode(file("dockersetup.sh"))

}




# jenkins slave sg
resource "aws_security_group" "Jenkins_slave" {
  name        = "jenkins_slave_sg"
  description = "Allow jenkins master to access node via ssh"
  vpc_id      = aws_vpc.myvpc.id


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
  security_group_id            = aws_security_group.Jenkins_slave.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
  referenced_security_group_id = aws_security_group.Jenkins_master.id
}


resource "aws_vpc_security_group_egress_rule" "jenkins_slave_allowall_outbound" {
  security_group_id = aws_security_group.Jenkins_slave.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


#grafana monitoring security group
resource "aws_security_group" "monitoring_instance_sg" {
  name        = "monitoring_instance_sg"
  description = "Allow prometheus and grafana"
  vpc_id      = aws_vpc.myvpc.id


  tags = {
    Name = "monitoring instance"
  }
}


#Allow Prometheus UI access
resource "aws_vpc_security_group_ingress_rule" "allow_prometheusui_access" {
  security_group_id = aws_security_group.monitoring_instance_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 9090
  ip_protocol       = "tcp"
  to_port           = 9090
}

#Allow Grafana UI access
resource "aws_vpc_security_group_ingress_rule" "allow_grafanaui_access" {
  security_group_id            = aws_security_group.monitoring_instance_sg.id
  referenced_security_group_id = aws_security_group.websg.id
  from_port                    = 3000
  ip_protocol                  = "tcp"
  to_port                      = 3000
}

#Allow outbound
resource "aws_vpc_security_group_egress_rule" "monitoringinstance_allowall_outbound" {
  security_group_id = aws_security_group.monitoring_instance_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#ssh
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_monitoring" {
  security_group_id = aws_security_group.monitoring_instance_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


#Jenkins slave instance ap south 1a
module "ec2_instance_jenkinsslaveprodapsouth1a" {

  source           = "./modules/ec2_instance"
  instance_type    = "m7i-flex.large"
  ami              = "ami-01a00762f46d584a1"
  key_name         = "oldawskey"
  name             = "Jenkins Node Prod ap-south-1a"
  security_groups  = [aws_security_group.Jenkins_slave_prodinstance.id]
  subnet_id        = aws_subnet.subnet3.id
  user_data_base64 = base64encode(file("jenkinssetup.sh"))

}

#Jenkins slave instance ap south 1b
module "ec2_instance_jenkinsslaveprodapsouth1b" {

  source           = "./modules/ec2_instance"
  instance_type    = "m7i-flex.large"
  ami              = "ami-01a00762f46d584a1"
  key_name         = "oldawskey"
  name             = "Jenkins Node Prod ap-south-1b"
  security_groups  = [aws_security_group.Jenkins_slave_prodinstance.id]
  subnet_id        = aws_subnet.subnet4.id
  user_data_base64 = base64encode(file("jenkinssetup.sh"))

}


resource "aws_security_group" "Jenkins_slave_prodinstance" {
  name        = "jenkins_slave_prod_sg"
  description = "Allow jenkins master to access node via ssh"
  vpc_id      = aws_vpc.myvpc.id


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
  security_group_id            = aws_security_group.Jenkins_slave_prodinstance.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
  referenced_security_group_id = aws_security_group.Jenkins_master.id
}

#allow ssh to jenkins slave machine
resource "aws_vpc_security_group_ingress_rule" "allow_flaskappui_access" {
  security_group_id            = aws_security_group.Jenkins_slave_prodinstance.id
  referenced_security_group_id = aws_security_group.websg.id
  from_port                    = 5000
  ip_protocol                  = "tcp"
  to_port                      = 5000
}


#Allow Node exporter UI access
resource "aws_vpc_security_group_ingress_rule" "allow_nodeexporterui_access" {
  security_group_id            = aws_security_group.Jenkins_slave_prodinstance.id
  referenced_security_group_id = aws_security_group.monitoring_instance_sg.id
  from_port                    = 9100
  ip_protocol                  = "tcp"
  to_port                      = 9100
}

resource "aws_vpc_security_group_egress_rule" "jenkins_slave2_allowall_outbound" {
  security_group_id = aws_security_group.Jenkins_slave_prodinstance.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#Alb
resource "aws_lb" "myalb" {
  name               = "myalb1"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.websg.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  enable_deletion_protection = false
}


#Security group alb

resource "aws_security_group" "websg" {

  vpc_id = aws_vpc.myvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}


#alb target group
resource "aws_lb_target_group" "myalbtg" {
  name     = "myalbtgname"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

#alb listener
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.myalbtg.arn
  }
}


#alb target group attachment
resource "aws_lb_target_group_attachment" "tgattachment1" {
  target_group_arn = aws_lb_target_group.myalbtg.arn
  target_id        = module.ec2_instance_jenkinsslaveprodapsouth1a.instance_id
  port             = 5000
}
#alb target group attachment2
resource "aws_lb_target_group_attachment" "tgattachment2" {
  target_group_arn = aws_lb_target_group.myalbtg.arn
  target_id        = module.ec2_instance_jenkinsslaveprodapsouth1b.instance_id
  port             = 5000
}

#grafana target group since moving instance to private subnets. access grafana via exiting alb

#alb target group
resource "aws_lb_target_group" "myalbtggrafana" {
  name     = "myalbtggrafana"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/api/health" # grafana health check endpoint
    port = "traffic-port"
  }
}

#alb listener rule : this allows the existing alb listener to send traffic to another target group based on path /garfana
resource "aws_lb_listener_rule" "grafanalistenerrule" {
  listener_arn = aws_lb_listener.front_end.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.myalbtggrafana.arn
  }

  condition {
    path_pattern {
      values = ["/grafana", "/grafana/*"]
    }
  }

}

#alb target group attachment
resource "aws_lb_target_group_attachment" "tgattachmentgrafana" {
  target_group_arn = aws_lb_target_group.myalbtggrafana.arn
  target_id        = module.ec2_instance_grafanaandprometheus.instance_id
  port             = 3000
}


#grafana monitoring instance
module "ec2_instance_grafanaandprometheus" {

  source           = "./modules/ec2_instance"
  instance_type    = "m7i-flex.large"
  ami              = "ami-01a00762f46d584a1"
  key_name         = "oldawskey"
  name             = "Grafana monitoring"
  security_groups  = [aws_security_group.monitoring_instance_sg.id]
  subnet_id        = aws_subnet.subnet3.id
  user_data_base64 = base64encode(file("prometheusgrafana.sh"))

}




output "loadbalancerdns" {
  value = aws_lb.myalb.dns_name
}


