provider "aws" {}

# IP var should be provided via tf CLI command execution, i.e. terraform plan -var 'my_ip=192.158.1.38/32'
variable "my_ip" {}

data "aws_vpc" "get_vpc" {
  default = true
}

data "aws_subnets" "get_subnets" {
  filter {
    name   = "default-for-az"
    values = [true]
  }
}

data "aws_subnet" "subnet_ids" {
  for_each = toset(data.aws_subnets.get_subnets.ids)
  id       = each.value
}

locals {
  subnets_ids = [for subnet in data.aws_subnet.subnet_ids : subnet.id]
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

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # Amazon
}

resource "aws_key_pair" "ec2_ssh_key" {
  key_name   = "ec2-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "ssh_80" {
  name        = "ssh-8080"
  description = "Allow SSH and port 8080"
  vpc_id      = data.aws_vpc.get_vpc.id

  ingress {
    description = "Jenkins 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

resource "aws_instance" "ubuntu_server" {
  count                       = 0
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2_ssh_key.key_name
  subnet_id                   = local.subnets_ids[0]
  vpc_security_group_ids      = [aws_security_group.ssh_80.id]
}

resource "aws_instance" "amazon_linux_server" {
  count                       = 1
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2_ssh_key.key_name
  subnet_id                   = local.subnets_ids[0]
  vpc_security_group_ids      = [aws_security_group.ssh_80.id]
}

resource "null_resource" "run_ansible_amazon_linux" {
  triggers = {
    public_ips = join(",", aws_instance.amazon_linux_server[*].public_ip)
  }

  provisioner "local-exec" {
    working_dir = "ansible"
    command = length(aws_instance.amazon_linux_server) != 0 ? "ansible-playbook --inventory ${join(",", aws_instance.amazon_linux_server[*].public_ip)}, --user ec2-user install_run_jenkins.yaml" : "echo 'There is no Amazon Linux servers'"
  }
}

resource "null_resource" "run_ansible_ubuntu" {
  triggers = {
    public_ips = join(",", aws_instance.ubuntu_server[*].public_ip)
  }

  provisioner "local-exec" {
    working_dir = "ansible"
    command = length(aws_instance.ubuntu_server) != 0 ? "ansible-playbook --inventory ${join(",", aws_instance.ubuntu_server[*].public_ip)}, --user ubuntu install_run_jenkins.yaml" : "echo 'There is no Ubuntu servers'"
  }
}

output "ec2_ips" {
  value = concat(aws_instance.ubuntu_server[*].public_ip, aws_instance.amazon_linux_server[*].public_ip)
}