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

variable "iam_instance_profile" {
    type = string
    description = "IAM instance profile"
    default = null
  
}

variable "subnet_id" {

    type = string
    description = "subnet id"
  
}

variable "user_data_base64" {
    type = string
    description = "user data script file "
  
}