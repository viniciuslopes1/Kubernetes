#Header
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "sa-east-1"
  access_key = "xxxxxxx" #Put your credentials
  secret_key = "xxxxxxxx" #Put your credentials
}


# Create a VPC
resource "aws_vpc" "VPC_Default" {
  cidr_block = "10.0.0.0/16"
}

# Create Subnet
resource "aws_subnet" "Subnet1" {
  vpc_id     = aws_vpc.VPC_Default.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "Subnet1"
  }
}

#Create Security Group to MYSQL
resource "aws_security_group" "allow_sql" {
  name        = "allow_sql"
  description = "Allow SQL inbound traffic"
  vpc_id      = aws_vpc.VPC_Default.id

  ingress {
    description = "MYSQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.VPC_Default.cidr_block]
  }
}
#Create Security Group to NGINX
resource "aws_security_group" "allow_nginx" {
  name        = "allow_nginx"
  description = "Allow Nginx inbound traffic"
  vpc_id      = aws_vpc.VPC_Default.id

  ingress {
    description = "NGINX from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.VPC_Default.cidr_block]
  }
}

#Create Cluster with EKS
module "eks" {
  source       = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=v12.1.0"
  cluster_name = "Cluster_Kubernetes"
  vpc_id       = aws_vpc.VPC_Default.id
  subnets      = aws_subnet.Subnet1.id

  worker_groups = [
  {
    name                          = "MySQL"
    instance_type                 = "t2.small"
    additional_userdata           = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y mariadb-server
              systemctl enable mariadb
              systemctl start mariadb
              EOF
    asg_desired_capacity          = 1
    additional_security_group_ids = [aws_security_group.allow_sql.id]
  },
  {
    name                          = "NGINX"
    instance_type                 = "t2.medium"
    additional_userdata           = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nginx
              systemctl enable nginx
              systemctl start nginx
              EOF
    additional_security_group_ids = [aws_security_group.allow_nginx.id]
    asg_desired_capacity          = 2
  },
]

  manage_aws_auth = false
}
