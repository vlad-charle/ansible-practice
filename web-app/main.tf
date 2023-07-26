provider "aws" {}

# IP var should be provided via tf CLI command execution, i.e. terraform plan -var 'my_ip=192.158.1.38/32'
variable "my_ip" {}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "random_integer" "az" {
  min = 0
  max = length(data.aws_availability_zones.available.names) - 1
}

resource "aws_vpc" "vpc" {
  cidr_block         = "10.0.0.0/16"
  enable_dns_support = true
}

resource "aws_subnet" "public_subnet" {
  availability_zone = data.aws_availability_zones.available.names[random_integer.az.result]
  cidr_block        = "10.0.0.0/17"
  vpc_id            = aws_vpc.vpc.id
}

resource "aws_subnet" "private_subnet" {
  availability_zone = data.aws_availability_zones.available.names[random_integer.az.result]
  cidr_block        = "10.0.128.0/17"
  vpc_id            = aws_vpc.vpc.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_eip" "nat_ip" {
  domain = "vpc"
  depends_on = [
    aws_internet_gateway.igw
  ]
}

resource "aws_nat_gateway" "nat" {
  allocation_id     = aws_eip.nat_ip.allocation_id
  connectivity_type = "public"
  subnet_id         = aws_subnet.public_subnet.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "public_routes_to_subnets" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_routes_to_subnets" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "ec2_ssh_key" {
  key_name   = "ec2-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "java_app_sg" {
  name        = "ssh-8080"
  description = "Allow SSH and port 8080"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "java-app 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "SSH"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = [var.my_ip]
    security_groups = [aws_security_group.ansible_node_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "java_app_server" {
  count                       = 1
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2_ssh_key.key_name
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.java_app_sg.id]

  tags = {
    Role = "web_app_server"
    Name = "app"
  }
}

resource "aws_security_group" "ansible_node_sg" {
  name        = "ssh"
  description = "Allow SSH"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "ansible_node_server" {
  count                       = 1
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2_ssh_key.key_name
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.ansible_node_sg.id]

  user_data = <<EOF
#!/bin/bash

apt update && apt install ansible python3-pip openjdk-17-jre -y
pip install boto3 botocore
cd /home/ubuntu/ && git clone https://github.com/vlad-charle/ansible-practice.git

#create file for AWS creds
mkdir .aws && touch /home/ubuntu/.aws/credentials
chown -R ubuntu:ubuntu /home/ubuntu/.aws/credentials
EOF

  tags = {
    Role = "ansible_controle_node_server"
    Name = "ansible"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "mysql"
  description = "Allow MySQL from java-app SG"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "MySQL"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.java_app_sg.id]
  }
  
  ingress {
    description     = "SSH"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.ansible_node_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "db_server" {
  count                       = 1
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.ec2_ssh_key.key_name
  subnet_id                   = aws_subnet.private_subnet.id
  vpc_security_group_ids      = [aws_security_group.db_sg.id]

  tags = {
    Role = "db_server"
    Name = "DB"
  }
}

output "ansible_node_server_ip" {
  value = aws_instance.ansible_node_server[*].public_ip
}

output "java_app_server_ip" {
  value = concat(aws_instance.java_app_server[*].public_ip, aws_instance.java_app_server[*].private_ip)
}

output "db_server_ip" {
  value = aws_instance.db_server[*].private_ip
}