# Security group to ECS Task
resource "aws_security_group" "ecs_tasks" {
  name   = "${var.application_name}-sg-ecs-task-${terraform.workspace}"
  vpc_id = var.vpc_id

  ingress {
    protocol         = "tcp"
    from_port        = var.insecure_port
    to_port          = var.insecure_port
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name        = "${var.application_name}-sg-ecs-task-${terraform.workspace}"
    Environment = "${terraform.workspace}"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.application_name}-cluster-${terraform.workspace}"

  tags = {
    Name        = "${var.application_name}-cluster-${terraform.workspace}"
    Environment = "${terraform.workspace}"
  }
}

# IAM Policy document
data "aws_iam_policy_document" "policy" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
# IAM Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.application_name}-ecsTaskExecutionRole-${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.policy.json
}

# IAM Role policy attachment
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Template file for container definitions
data "template_file" "container_definitions" {
  template = file("${path.module}/task-definitions/service.json.tpl")

  vars = {
    container_name  = "${var.application_name}-container-${terraform.workspace}"
    container_image = "${var.repository_url}:latest"
    container_port  = var.container_port
  }
}

# Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.application_name}-task-${terraform.workspace}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = data.template_file.container_definitions.rendered
  tags = {
    Name        = "${var.application_name}-task-${terraform.workspace}"
    Environment = "${terraform.workspace}"
  }
}