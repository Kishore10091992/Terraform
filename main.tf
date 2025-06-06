terraform {
  required_providers {
    aws = {
     source = "hashicorp/aws"
     version = "~>5.0"
     }
    }
  }

provider "aws" {
 region = "us-east-1"
 }

resource "aws_vpc" "Terraform_vpc" {
 cidr_block = "172.168.0.0/16"

  tags = {
  Name = "Terraform_vpc"
  }
}

resource "aws_subnet" "Terraform_pubsub" {
  vpc_id = aws_vpc.Terraform_vpc.id
  cidr_block = "172.168.0.0/24"

  tags = {
  Name = "Terraform_pubsub"
  }
}

resource "aws_subnet" "Terraform_prisub" {
  vpc_id = aws_vpc.Terraform_vpc.id
  cidr_block = "172.168.1.0/24"

  tags = {
  Name = "Terraform_prisub"
  }
}

resource "aws_internet_gateway" "Terraform_IGW" {
  vpc_id = aws_vpc.Terraform_vpc.id

  tags = {
  Name = "Terraform_IGW"
  }
}

resource "aws_route_table" "Terraform_pubrt" {
  vpc_id = aws_vpc.Terraform_vpc.id
route {
 cidr_block = "0.0.0.0/0"
 gateway_id = aws_internet_gateway.Terraform_IGW.id
  }

  tags = {
  Name = "Terraform_pubrt"
  }
}

resource "aws_route_table" "Terraform_prirt" {
  vpc_id = aws_vpc.Terraform_vpc.id

tags = {
 Name = "Terraform_prirt"
 }
}

resource "aws_route_table_association" "pubsub" {
  subnet_id      = aws_subnet.Terraform_pubsub.id
  route_table_id = aws_route_table.Terraform_pubrt.id
}

resource "aws_route_table_association" "prisub" {
  subnet_id      = aws_subnet.Terraform_prisub.id
  route_table_id = aws_route_table.Terraform_prirt.id
}

resource "aws_security_group" "Terraform_sg" {
  vpc_id = aws_vpc.Terraform_vpc.id

tags = {
  Name = "Terraform_sg"
 }
}

resource "aws_vpc_security_group_ingress_rule" "allow_all" {
  security_group_id = aws_security_group.Terraform_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
}

resource "aws_vpc_security_group_ingress_rule" "allow_tcp" {
  security_group_id = aws_security_group.Terraform_sg.id
  cidr_ipv4         = aws_vpc.Terraform_vpc.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.Terraform_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
}

resource "aws_key_pair" "Terraform_keypair" {
  key_name   = "Terraform_keypair"
  public_key = file("~/.ssh/id_rsa.pub")

  tags = {
   Name = "Terraform_keypair"
  }
}

resource "aws_network_interface" "primary" {
  subnet_id       = aws_subnet.Terraform_pubsub.id
  security_groups = [aws_security_group.Terraform_sg.id]
}

resource "aws_eip" "public_ip" {
  vpc = true
  network_interface = aws_network_interface.primary.id
}

resource "aws_network_interface" "secondary" {
  subnet_id = aws_subnet.Terraform_prisub.id
}

resource "aws_instance" "Terraform_Ec2_Instance" {
  ami           = "ami-0e449927258d45bc4"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.Terraform_keypair.key_name

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.primary.id
  }

  network_interface {
    device_index         = 1
    network_interface_id = aws_network_interface.secondary.id
  }

  user_data =<<-EOF
   sudo yum update -y
   sudo yum install -y httpd
   systemctl start httpd
   systemctl enable httpd
   echo "Hello world from Terraform!" > /var/www/html/index.html
   EOF

  tags = {
    Name = "Terraform_Ec2_Instance"
  }
}
