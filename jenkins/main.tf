locals {
  name        = "utility"
  domain_name = "gatsby-devops.com"
}

# Create VPC and two Public Subnets for Jenkins Server 
resource "aws_vpc" "jenkins_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${local.name}-vpc"
  }
}

resource "aws_subnet" "jenkins_pub_subnet_1" {
  vpc_id     = aws_vpc.jenkins_vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "${local.name}-pub-subnet-1"
  }
}

resource "aws_subnet" "jenkins_pub_subnet_2" {
  vpc_id     = aws_vpc.jenkins_vpc.id
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "${local.name}-pub-subnet-2"
  }
}

# Create Internet Gateway for public subnet
resource "aws_internet_gateway" "jenkins_igw" {
  vpc_id = aws_vpc.jenkins_vpc.id
  tags = {
    Name = "${local.name}-igw"
  }
}

# Create Route Table for public subnet1 and public subnet 2 associate it with the Internet Gateway
resource "aws_route_table" "jenkins_pub_rt_1" {
  vpc_id = aws_vpc.jenkins_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins_igw.id
  }
  tags = {
    Name = "${local.name}-pub-rt-1"
  }
}

resource "aws_route_table" "jenkins_pub_rt_2" {
  vpc_id = aws_vpc.jenkins_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins_igw.id
  }
  tags = {
    Name = "${local.name}-pub-rt-2"
  }
}

resource "aws_route_table_association" "jenkins_pub_rta_1" {
  subnet_id      = aws_subnet.jenkins_pub_subnet_1.id
  route_table_id = aws_route_table.jenkins_pub_rt_1.id
}

resource "aws_route_table_association" "jenkins_pub_rta_2" {
  subnet_id      = aws_subnet.jenkins_pub_subnet_2.id
  route_table_id = aws_route_table.jenkins_pub_rt_2.id
}

# fetch the latest Redhat AMI for the region
data "aws_ami" "redhat" {
  most_recent = true
  filter {
    name   = "name"
    values = ["RHEL-8.*_HVM-*-x86_64-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["309956199498"] # Redhat's AWS account ID
}

# Create tls key pair for Jenkins Server
resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# create local file to store the private key
resource "local_file" "jenkins_private_key" {
  content         = tls_private_key.jenkins_key.private_key_pem
  filename        = "${local.name}-jenkins_key.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "jenkins_key" {
  key_name   = "${local.name}-jenkins-key"
  public_key = tls_private_key.jenkins_key.public_key_openssh
}

# Create Jenkins EC2 Instance in the public subnet
resource "aws_instance" "jenkins_server" {
  ami                         = data.aws_ami.redhat.id # Redhat AMI
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.jenkins_pub_subnet_1.id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.jenkins_key.key_name
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins_instance_profile.name
  user_data                   = templatefile("${path.module}/userdata.sh", {
    region = "eu-west-3"
  })
  tags = {
    Name = "${local.name}-jenkins-server"
  }
}

# Create Security Group for Jenkins Server (aLLOW PORT 8080 FROM ALB)
resource "aws_security_group" "jenkins_sg" {
  name        = "${local.name}-jenkins-sg"
  description = "Allow traffic to Jenkins Server"
  vpc_id      = aws_vpc.jenkins_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [ aws_security_group.alb_sg.id ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-jenkins-sg"
  }
}

# Create Security Group for ALB (allow port 80 and 443 from anywhere)
resource "aws_security_group" "alb_sg" {
  name        = "${local.name}-alb-sg"
  description = "Allow traffic to ALB"
  vpc_id      = aws_vpc.jenkins_vpc.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-alb-sg"
  }
}

# Create Classic Load Balancer for Jenkins Server
resource "aws_elb" "jenkins_alb" {
  name            = "${local.name}-jenkins-elb"
  subnets         = [aws_subnet.jenkins_pub_subnet_1.id]
  security_groups = [aws_security_group.alb_sg.id]

  listener {
    instance_port      = 8080
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.acm_cert.arn
  }

  health_check {
    target              = "tcp:8080"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  instances                   = [aws_instance.jenkins_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "${local.name}-jenkins-elb"
  }
}

# Create A record for Jenkins Server in Route53 pointing to the ALB
resource "aws_route53_record" "jenkins_dns" {
  zone_id = data.aws_route53_zone.route53_zone.id
  name    = "jenkins.${local.domain_name}"
  type    = "A"
  alias {
    name                   = aws_elb.jenkins_alb.dns_name
    zone_id                = aws_elb.jenkins_alb.zone_id
    evaluate_target_health = true
  }
}

#Create IAM Role for Jenkins Server to access S3 and ECR
resource "aws_iam_role" "jenkins_role" {
  name = "${local.name}-jenkins-role4"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach Policy for Jenkins
resource "aws_iam_role_policy_attachment" "admin_policy" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach IAM Role to Jenkins Server
resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name = "${local.name}-jenkins-instance-profile4"
  role = aws_iam_role.jenkins_role.name
}

# Importing Route 53 hosted zone
data "aws_route53_zone" "route53_zone" {
  name         = local.domain_name
  private_zone = false
}

# Getting the certificate from ACM
resource "aws_acm_certificate" "acm_cert" {
  domain_name               = local.domain_name
  subject_alternative_names = ["*.${local.domain_name}"]
  validation_method         = "DNS"
  tags = {
    Name = "${local.name}-acm-cert"
  }
}

resource "aws_route53_record" "validate-record" {
  for_each = {
    for dvo in aws_acm_certificate.acm_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.route53_zone.id
}
resource "aws_acm_certificate_validation" "cert-validation" {
  certificate_arn         = aws_acm_certificate.acm_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.validate-record : record.fqdn]
}
