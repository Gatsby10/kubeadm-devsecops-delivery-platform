#Data block for Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#Creating HAProxy Instance
resource "aws_instance" "haproxy" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.medium"
  key_name               = var.key_name
  subnet_id              = element(var.subnet_ids, count.index)
  vpc_security_group_ids = [aws_security_group.haproxy_sg.id]
  user_data              = templatefile("${path.module}/userdata.sh", {
    master_ip_1 = var.master_ip_1,
    master_ip_2 = var.master_ip_2,
    master_ip_3 = var.master_ip_3
  })
  tags = {
    Name = "${var.name}-haproxy-${count.index + 1}"
  }
}

# Creating HAProxy Security Group
resource "aws_security_group" "haproxy_sg" {
  name        = "${var.name}-haproxy-sg"
  description = "HAProxy for Kubernetes API"
  vpc_id      = var.vpc_id

  ingress {
    description = "Kubernetes API access"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description     = "SSH access"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg, var.ansible_sg]
  }

  egress {
    description = "General outbound internet/NAT access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-haproxy-sg"
  }
}
