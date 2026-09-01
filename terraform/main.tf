terraform {
  terraform {
    backend "s3" {
      bucket = "my-own-nice-portfolio-tf-state" # Must be a globally unique name
      key    = "prod/terraform.tfstate"
      region = "us-east-1"
    }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Variable for SSH Key to make the code portable
variable "public_key_path" {
  description = "Path to the public SSH key"
  default     = "~/.ssh/id_ed25519.pub"
}

# 1. SSH Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file(var.public_key_path)
}

# 2. Debian 12 AMI
data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"] # Official Debian Account ID

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Web hosting
resource "aws_security_group" "web_sg" {
  name        = "portfolio_sg"
  description = "Allow SSH, HTTP, HTTPS, and WireGuard"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.debian.id
  instance_type          = "t3.micro" 
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  # Protect your permanent server from `terraform destroy`
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "Debian-Web-Server"
  }
}

# Assign a permanent static IP
resource "aws_eip" "web_eip" {
  instance = aws_instance.web.id
  domain   = "vpc"
}

# Output the IP to use in your Ansible inventory
output "server_public_ip" {
  value = aws_eip.web_eip.public_ip
}
