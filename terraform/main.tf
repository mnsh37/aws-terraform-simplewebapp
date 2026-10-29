provider "aws" {
  region = "us-east-1" # Change this if your AWS console is using a different region
}

# 1. Security Group to allow web traffic (80) and SSH (22)
resource "aws_security_group" "prod_web_sg" {
  name        = "prod-web-sg"
  description = "Allow HTTP and SSH traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

# 2. Find the latest Ubuntu 22.04 image
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 3. Upload your public SSH key to AWS
resource "aws_key_pair" "deploy_key" {
  key_name   = "github-actions-deploy-key"
  public_key = file("${path.module}/prod_key.pub")
}

# 4. Create the Production EC2 Server
resource "aws_instance" "prod_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deploy_key.key_name
  vpc_security_group_ids = [aws_security_group.prod_web_sg.id]

  # Install a web server (Nginx) when the instance first boots
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              chown -R ubuntu:ubuntu /var/www/html
              EOF

  tags = {
    Name = "Production-Web-Server"
  }
}

# 5. Print out the server's public IP address
output "server_public_ip" {
  value = aws_instance.prod_server.public_ip
}