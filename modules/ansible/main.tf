# SECURITY GROUP
resource "aws_security_group" "ansible_sg" {
  name        = "ansible-sg"
  description = "Security group for Ansible Control Node"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

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

# Create EC2 instance for Ansible Control Node
resource "aws_instance" "ansible_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ansible_profile.id
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  user_data              = templatefile("${path.module}/userdata.sh", {
    privatekey = var.privatekey,
    bucket_name = var.bucket_name,
    master1_ip = var.master1_ip,
    master2_ip = var.master2_ip,
    master3_ip = var.master3_ip,
    worker1_ip = var.worker1_ip,
    worker2_ip = var.worker2_ip,
    worker3_ip = var.worker3_ip,
    haproxy1_ip = var.haproxy1_ip,
    haproxy2_ip = var.haproxy2_ip
  })
  tags = {
    Name = "${var.name}-ansible-server"
  }
}

# Create IAM role for SSM
resource "aws_iam_role" "s3_role" {
  name = "${var.name}-ansible-role7"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach the SSM policy to the role
resource "aws_iam_role_policy_attachment" "s3_policy" {
  role       = aws_iam_role.s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# create instance profile
resource "aws_iam_instance_profile" "ansible_profile" {
  name = "${var.name}-ansible-instance-profile4"
  role = aws_iam_role.s3_role.name
}

resource "aws_s3_object" "object" {
  for_each = fileset("${path.module}/playbooks", "*")
  bucket = var.bucket_name
  key    = "playbooks/${each.value}"
  source = "${path.module}/playbooks/${each.value}"
  etag = filemd5("${path.module}/playbooks/${each.value}")
}
