variable "region"            { default = "us-east-1" }
variable "vpc_cidr"          { default = "10.0.0.0/16" }
variable "public_cidr"       { default = "10.0.1.0/24" }
variable "private_cidr"      { default = "10.0.2.0/24" }
variable "az"                { default = "us-east-1a" }

# Use an existing keypair name that already exists in AWS
variable "ssh_key_name"      { default = "ubuntu-slave-jen" }
variable "private_key_path"  { default = "/home/ubuntu/.ssh/ubuntu-slave-jen.pem" }

variable "bastion_ami"       { default = "ami-020cba7c55df1f615" }
variable "mongo_ami"         { default = "ami-020cba7c55df1f615" }
