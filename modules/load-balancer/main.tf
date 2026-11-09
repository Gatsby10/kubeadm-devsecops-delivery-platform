########################################
# Application Load Balancer for the stage environment.
# This receives external client traffic and forwards it to the worker nodes.
########################################

# SECURITY GROUP
resource "aws_security_group" "stage_sg" {
  name        = "${var.name}-stage-sg"
  description = "Security group for Stage Environment"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTPS traffic from anywhere"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-stage-sg"
  }
}

resource "aws_lb" "stage_env" {
  name               = "${var.name}-stage-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.stage_sg.id]
  subnets            = var.public_subnet_ids
  enable_deletion_protection = false
  tags = {
      Name        = "${var.name}-stage-alb"
      Environment = "stage"
  }
}

########################################
# Target group for the stage environment backend.
# Traffic from the listeners is forwarded to this target group on port 3001.
########################################
resource "aws_lb_target_group" "stage_env" {
  name        = "${var.name}-stage-tg"
  port        = 30000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  health_check {
    enabled             = true
    interval            = 30
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
  }
  tags = {
      Name        = "${var.name}-stage-tg"
      Environment = "stage"
  }
}

########################################
# Attachment of worker node targets to the target group.
# Each worker node is registered on port 30000 so the ALB can route traffic to it.
########################################
resource "aws_lb_target_group_attachment" "stage_env_workers" {
  count = length(var.worker_node_ids)
  target_group_arn = aws_lb_target_group.stage_env.arn
  target_id        = var.worker_node_ids[count.index]
  port             = 30000
}

########################################
# HTTP listener for the load balancer.
# This accepts plain HTTP traffic on port 80 and forwards it to the target group.
########################################
resource "aws_lb_listener" "stage_env_http" {
  load_balancer_arn = aws_lb.stage_env.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage_env.arn
  }
}

########################################
# HTTPS listener for the load balancer.
# This accepts TLS traffic on port 443, uses the provided ACM certificate ARN,
# and forwards decrypted traffic to the same target group.
########################################
resource "aws_lb_listener" "stage_env_https" {
  load_balancer_arn = aws_lb.stage_env.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.ssl_certificate_arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage_env.arn
  }
}

# SECURITY GROUP
resource "aws_security_group" "production_sg" {
  name        = "${var.name}-production-sg"
  description = "Security group for Production Environment"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTPS traffic from anywhere"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-production-sg"
  }
}

########################################
# Application Load Balancer for the production environment.
# This receives external client traffic and forwards it to the worker nodes.
########################################
resource "aws_lb" "production_env" {
  name               = "${var.name}-production-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.production_sg.id]
  subnets            = var.public_subnet_ids
  enable_deletion_protection = false
  tags = {
      Name        = "${var.name}-production-alb"
      Environment = "production"
  }
}

########################################
# Target group for the production environment backend.
# Traffic from the listeners is forwarded to this target group on port 30002.
########################################
resource "aws_lb_target_group" "production_env" {
  name        = "${var.name}-production-tg"
  port        = 30001
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id
  health_check {
    enabled             = true
    interval            = 30
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
  }
  tags = {
      Name        = "${var.name}-production-tg"
      Environment = "production"
  }
}

########################################
# Attachment of worker node targets to the target group.
# Each worker node is registered on port 30001 so the ALB can route traffic to it.
########################################
resource "aws_lb_target_group_attachment" "production_env_workers" {
  count = length(var.worker_node_ids)
  target_group_arn = aws_lb_target_group.production_env.arn
  target_id        = var.worker_node_ids[count.index]
  port             = 30001
}

########################################
# HTTP listener for the load balancer.
# This accepts plain HTTP traffic on port 80 and forwards it to the target group.
########################################
resource "aws_lb_listener" "production_http" {
  load_balancer_arn = aws_lb.production_env.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.production_env.arn
  }
}

########################################
# HTTPS listener for the load balancer.
# This accepts TLS traffic on port 443, uses the provided ACM certificate ARN,
# and forwards decrypted traffic to the same target group.
########################################
resource "aws_lb_listener" "production_https" {
  load_balancer_arn = aws_lb.production_env.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.ssl_certificate_arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.production_env.arn
  }
}

# SECURITY GROUP
resource "aws_security_group" "promethues_sg" {
  name        = "${var.name}-prometheus-sg"
  description = "Security group for Prometheus Environment"
  vpc_id      = var.vpc_id
  ingress {
    description = "Allow HTTPS traffic from anywhere"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-prometheus-sg"
  }
}

########################################
# Application Load Balancer for the prometheus pod.
# This receives external client traffic and forwards it to the worker nodes.
########################################
resource "aws_lb" "prometheus_env" {
  name               = "${var.name}-prometheus-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.promethues_sg.id]
  subnets            = var.public_subnet_ids
  enable_deletion_protection = false
  tags = {
      Name        = "${var.name}-prometheus-alb"
      Environment = "prometheus"
  }
}

########################################
# Target group for the prometheus pod backend.
# Traffic from the listeners is forwarded to this target group on port 31090.
########################################
resource "aws_lb_target_group" "prometheus_env" {
  name        = "${var.name}-prometheus-tg"
  port        = 31090
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id
  health_check {
    enabled             = true
    interval            = 30
    protocol            = "HTTP"
    path                = "/-/healthy"
    matcher             = "200"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
  }
  tags = {
      Name        = "${var.name}-prometheus-tg"
      Environment = "prometheus"
  }
}

########################################
# Attachment of worker node targets to the target group.
# Each worker node is registered on port 31090 so the ALB can route traffic to it.
########################################
resource "aws_lb_target_group_attachment" "prometheus_env_workers" {
  count = length(var.worker_node_ids)
  target_group_arn = aws_lb_target_group.prometheus_env.arn
  target_id        = var.worker_node_ids[count.index]
  port             = 31090
}

########################################
# HTTP listener for the load balancer.
# This accepts plain HTTP traffic on port 80 and forwards it to the target group.
########################################
resource "aws_lb_listener" "prometheus_http" {
  load_balancer_arn = aws_lb.prometheus_env.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus_env.arn
  }
}

########################################
# HTTPS listener for the load balancer.
# This accepts TLS traffic on port 443, uses the provided ACM certificate ARN,
# and forwards decrypted traffic to the same target group.
########################################
resource "aws_lb_listener" "prometheus_https" {
  load_balancer_arn = aws_lb.prometheus_env.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.ssl_certificate_arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus_env.arn
  }
}

# SECURITY GROUP
resource "aws_security_group" "grafana_sg" {
  name        = "${var.name}-grafana-sg"
  description = "Security group for Grafana Environment"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTPS traffic from anywhere"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-grafana-sg"
  }
}

########################################
# Application Load Balancer for the grafana pod.
# This receives external client traffic and forwards it to the worker nodes.
########################################
resource "aws_lb" "grafana_env" {
  name               = "${var.name}-grafana-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.grafana_sg.id]
  subnets            = var.public_subnet_ids
  enable_deletion_protection = false
  tags = {
      Name        = "${var.name}-grafana-alb"
      Environment = "grafana"
  }
}

########################################
# Target group for the grafana pod backend.
# Traffic from the listeners is forwarded to this target group on port 31300.
########################################
resource "aws_lb_target_group" "grafana_env" {
  name        = "${var.name}-grafana-tg"
  port        = 31300
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id
  health_check {
    enabled             = true
    interval            = 30
    protocol            = "HTTP"
    path                = "/api/health"
    matcher             = "200"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
  }
  tags = {
      Name        = "${var.name}-grafana-tg"
      Environment = "grafana"
  }
}

########################################
# Attachment of worker node targets to the target group.
# Each worker node is registered on port 31300 so the ALB can route traffic to it.
########################################
resource "aws_lb_target_group_attachment" "grafana_pod_workers" {
  count = length(var.worker_node_ids)
  target_group_arn = aws_lb_target_group.grafana_env.arn
  target_id        = var.worker_node_ids[count.index]
  port             = 31300
}

########################################
# HTTP listener for the load balancer.
# This accepts plain HTTP traffic on port 80 and forwards it to the target group.
########################################
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.grafana_env.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana_env.arn
  }
}

########################################
# HTTPS listener for the load balancer.
# This accepts TLS traffic on port 443, uses the provided ACM certificate ARN,
# and forwards decrypted traffic to the same target group.
########################################
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.grafana_env.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.ssl_certificate_arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana_env.arn
  }
}

data "aws_route53_zone" "name" {
  name = "gaurav-devops.site"
  private_zone = false
}

resource "aws_route53_record" "stage_env" {
  zone_id = data.aws_route53_zone.name.zone_id
  name    = "stage.gaurav-devops.site"
  type    = "A"
  alias {
    name                   = aws_lb.stage_env.dns_name
    zone_id                = aws_lb.stage_env.zone_id
    evaluate_target_health = true
  } 
}

resource "aws_route53_record" "production_env" {
  zone_id = data.aws_route53_zone.name.zone_id
  name    = "production.gaurav-devops.site"
  type    = "A"
  alias {
    name                   = aws_lb.production_env.dns_name
    zone_id                = aws_lb.production_env.zone_id
    evaluate_target_health = true
  } 
}

resource "aws_route53_record" "prometheus_env" {
  zone_id = data.aws_route53_zone.name.zone_id
  name    = "prometheus.gaurav-devops.site"
  type    = "A"
  alias {
    name                   = aws_lb.prometheus_env.dns_name
    zone_id                = aws_lb.prometheus_env.zone_id
    evaluate_target_health = true
  } 
}

resource "aws_route53_record" "grafana_env" {
  zone_id = data.aws_route53_zone.name.zone_id
  name    = "grafana.gaurav-devops.site"
  type    = "A"
  alias {
    name                   = aws_lb.grafana_env.dns_name
    zone_id                = aws_lb.grafana_env.zone_id
    evaluate_target_health = true
  } 
}
