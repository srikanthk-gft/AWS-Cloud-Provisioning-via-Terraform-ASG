# Deploy a sample "Hello GFT" in ASG with ELB

terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region = "us-east-2"
}

data "aws_availability_zones" "all" {}

# Create ASG

resource "aws_autoscaling_group" "gft-demo-asg" {
  launch_configuration = aws_launch_configuration.gft-demo-asg.id
  availability_zones   = data.aws_availability_zones.all.names

  min_size = 2
  max_size = 10

  load_balancers    = [aws_elb.gft-demo-asg.name]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "gft-demo-asgv"
    propagate_at_launch = true
  }
}

# Create a launch configuration for ASG

resource "aws_launch_configuration" "gft-demo-asg" {
  image_id        = "ami-0c55b159cbfafe1f0"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, from GFT" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  # For launch configuration with ASG set create_before_destroy = true.
  lifecycle {
    create_before_destroy = true
  }
}

# Create a SG for ASG

resource "aws_security_group" "instance" {
  name = "gft-demo-inst"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create ELB to route traffic across ASG

resource "aws_elb" "gft-demo-asg" {
  name               = "gft-demo-asgv"
  security_groups    = [aws_security_group.elb.id]
  availability_zones = data.aws_availability_zones.all.names

  health_check {
    target              = "HTTP:${var.server_port}/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  listener {
    lb_port           = var.elb_port
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }
}

# Create a SG for ELB

resource "aws_security_group" "elb" {
  name = "gft-demo-elb"

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.elb_port
    to_port     = var.elb_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}