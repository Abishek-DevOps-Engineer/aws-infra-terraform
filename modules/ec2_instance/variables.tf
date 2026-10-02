variable "ami" {
    type = string
    description = "ami of the instance"
}

variable "instance_type" {
    type = string
    description = "Ec2 instance type"
  
}

variable "key_name" {

    type = string
    description = "key pair name"
  
}

variable "name" {
    type = string
    description = "ec2_instance_name"
  
}

variable "security_groups" {
    type = set(string)
    description = "ec2_security_groups"
  
}

variable "source_path" {
    type = string
    description = "Source file path"
  
}

variable "destination_path" {
    type = string
    description = "destination file path"
  
}

variable "username" {
    type = string
    description = "ssh username"
  
}

variable "private_key_path" {
    type = string
    description = "private pem file path "
  
}

variable "iam_instance_profile" {
    type = string
    description = "IAM instance profile"
    default = null
  
}