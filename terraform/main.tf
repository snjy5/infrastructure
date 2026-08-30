terraform {
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

# 3. Security Group 
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Allow SSH and HTTP inbound traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. EC2 Instance
resource "aws_instance" "web" {
  ami                         = data.aws_ami.debian.id
  instance_type               = "t3.micro" 
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  
  # user_data is much safer and cleaner than remote-exec
  user_data = <<-EOF
              #!/bin/bash
              # Wait for potential boot-time apt locks to clear
              while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 5; done;
              
              apt-get update -y
              DEBIAN_FRONTEND=noninteractive apt-get install -y git ansible
              
              # Run as the default admin user rather than root
              su - admin -c "git clone --depth=1 https://github.com/snjy5/infrastructure /home/admin/infrastructure"
              cd /home/admin/infrastructure
              bash ansible.sh
              EOF

  # Connection block required for remote-exec to function properly
  connection {
    type        = "ssh"
    user        = "admin" # Default user for official Debian AMIs
    private_key = file("~/.ssh/id_ed25519") # Assuming this based on your local-exec command
    host        = self.public_ip
  }

  # 1. Wait for the background script to finish and prepare the log
  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "sudo cp /var/log/cloud-init-output.log /home/admin/deploy.log",
      "sudo chown admin:admin /home/admin/deploy.log"
    ]
  }

  # 2. Download the log file directly to your local device using scp
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 admin@${self.public_ip}:/home/admin/deploy.log ./ec2-deploy.log"
  }

  # Tags are optional but highly recommended
  tags = {
    Name = "Debian-Web-Server"
  }
}

