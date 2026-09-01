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

# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

# --- Variables ---

variable "public_key_path" {
  description = "Path to the public SSH key used to create the AWS key pair."
  default     = "~/.ssh/id_ed25519.pub"
}

# NEW: Added a variable for the Ansible user.
variable "ansible_user" {
  description = "The username that Ansible will use to connect to the server."
  type        = string
  default     = "admin" # The default user for Debian AMIs is 'admin'
}


# --- Resources ---

# 1. SSH Key Pair
# This resource uploads your public key to AWS, allowing you to SSH into the instance.
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file(var.public_key_path)
}

# 2. Debian 12 AMI Data Source
# This finds the latest official Debian 12 image to build the server from.
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

# 3. Security Group (Firewall)
# This defines the firewall rules for the server.
resource "aws_security_group" "web_sg" {
  name        = "portfolio_sg"
  description = "Allow SSH, HTTP, HTTPS, and WireGuard"

  # Ingress (inbound) rules
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow WireGuard"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress (outbound) rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allows all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. EC2 Instance
# This is the actual virtual server.
resource "aws_instance" "web" {
  ami                    = data.aws_ami.debian.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Protect your permanent server from accidental `terraform destroy`
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "Debian-Web-Server"
  }
}

# 5. Elastic IP
# This assigns a permanent, static public IP address to the instance.
resource "aws_eip" "web_eip" {
  instance = aws_instance.web.id
  domain   = "vpc" # Use 'vpc' for newer AWS accounts
}


# --- Automatic Ansible Inventory Generation ---

# This resource uses a template to create the production.ini file for Ansible.
# It runs after all the other resources are created.
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    # These are the variables passed into the template file
    host_ip      = aws_eip.web_eip.public_ip
    ssh_user     = var.ansible_user
    ssh_key_path = "~/.ssh/id_ed25519" # Use the standard path for the private key
  })
  # This sets the output path and filename
  filename = "../ansible/inventory/production.ini"
}


# --- Outputs ---

# Output the IP address to the console after a successful `terraform apply`
output "server_public_ip" {
  description = "The public IP address of the web server."
  value       = aws_eip.web_eip.public_ip
}
