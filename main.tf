provider "aws" {
region = "ap-south-1"
}

############################

# VPC

############################

resource "aws_vpc" "main" {
cidr_block = "10.0.0.0/16"

tags = {
Name = "bluegreen-vpc"
}
}

############################

# SUBNETS

############################

resource "aws_subnet" "subnet1" {
vpc_id                  = aws_vpc.main.id
cidr_block              = "10.0.1.0/24"
availability_zone       = "ap-south-1a"
map_public_ip_on_launch = true

tags = {
Name = "bluegreen-subnet1"
}
}

resource "aws_subnet" "subnet2" {
vpc_id                  = aws_vpc.main.id
cidr_block              = "10.0.2.0/24"
availability_zone       = "ap-south-1b"
map_public_ip_on_launch = true

tags = {
Name = "bluegreen-subnet2"
}
}

############################

# INTERNET GATEWAY

############################

resource "aws_internet_gateway" "igw" {
vpc_id = aws_vpc.main.id

tags = {
Name = "bluegreen-igw"
}
}

############################

# ROUTE TABLE

############################

resource "aws_route_table" "rt" {
vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet" {
route_table_id         = aws_route_table.rt.id
destination_cidr_block = "0.0.0.0/0"
gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "a1" {
subnet_id      = aws_subnet.subnet1.id
route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "a2" {
subnet_id      = aws_subnet.subnet2.id
route_table_id = aws_route_table.rt.id
}

############################

# SECURITY GROUP

############################

resource "aws_security_group" "ec2_sg" {

name   = "dotnet-sg"
vpc_id = aws_vpc.main.id

ingress {
description = "HTTP"
from_port   = 80
to_port     = 80
protocol    = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

ingress {
description = "SSH"
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

tags = {
Name = "dotnet-sg"
}
}

############################

# TARGET GROUPS

############################

resource "aws_lb_target_group" "blue" {
name     = "blue-tg-demo"
port     = 80
protocol = "HTTP"
vpc_id   = aws_vpc.main.id

health_check {
path                = "/"
interval            = 30
timeout             = 5
healthy_threshold   = 2
unhealthy_threshold = 2
matcher             = "200"
}
}

resource "aws_lb_target_group" "green" {
name     = "green-tg-demo"
port     = 80
protocol = "HTTP"
vpc_id   = aws_vpc.main.id

health_check {
path                = "/"
interval            = 30
timeout             = 5
healthy_threshold   = 2
unhealthy_threshold = 2
matcher             = "200"
}
}

############################

# S3 ARTIFACT BUCKET

############################

resource "aws_s3_bucket" "artifacts" {
bucket = "dotnet-bluegreen-artifacts-demo-604604739963"
}

############################

# IAM ROLES

############################

resource "aws_iam_role" "pipeline_role" {

name = "pipeline-role-demo"

assume_role_policy = jsonencode({
Version = "2012-10-17"
Statement = [{
Effect    = "Allow"
Principal = { Service = "codepipeline.amazonaws.com" }
Action    = "sts:AssumeRole"
}]
})
}

resource "aws_iam_role" "codebuild_role" {

name = "codebuild-role-demo"

assume_role_policy = jsonencode({
Version = "2012-10-17"
Statement = [{
Effect    = "Allow"
Principal = { Service = "codebuild.amazonaws.com" }
Action    = "sts:AssumeRole"
}]
})
}

resource "aws_iam_role" "codedeploy_role" {

name = "codedeploy-role-demo"

assume_role_policy = jsonencode({
Version = "2012-10-17"
Statement = [{
Effect    = "Allow"
Principal = { Service = "codedeploy.amazonaws.com" }
Action    = "sts:AssumeRole"
}]
})
}

############################

# EC2 ROLE

############################

resource "aws_iam_role" "ec2_role" {

name = "codedeploy-ec2-role"

assume_role_policy = jsonencode({
Version = "2012-10-17"
Statement = [{
Effect    = "Allow"
Principal = { Service = "ec2.amazonaws.com" }
Action    = "sts:AssumeRole"
}]
})
}

resource "aws_iam_role_policy_attachment" "codedeploy_ec2_policy" {
role       = aws_iam_role.ec2_role.name
policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
name = "codedeploy-ec2-profile"
role = aws_iam_role.ec2_role.name
}

############################

# AUTOSCALING GROUP

############################

resource "aws_autoscaling_group" "blue_asg" {

desired_capacity = 1
max_size         = 2
min_size         = 1

vpc_zone_identifier = [
aws_subnet.subnet1.id,
aws_subnet.subnet2.id
]

launch_template {
id      = aws_launch_template.app.id
version = "$Latest"
}

target_group_arns = [
aws_lb_target_group.blue.arn
]

tag {
key                 = "Name"
value               = "dotnet-bluegreen-instance"
propagate_at_launch = true
}
}

############################

# CODEDEPLOY APPLICATION

############################

resource "aws_codedeploy_app" "app" {

name             = "dotnet-bluegreen-demo"
compute_platform = "Server"
}

############################

# CODEBUILD

############################

resource "aws_codebuild_project" "build" {

name         = "dotnet-build"
service_role = aws_iam_role.codebuild_role.arn

artifacts {
type = "CODEPIPELINE"
}

environment {
compute_type = "BUILD_GENERAL1_SMALL"
image        = "aws/codebuild/standard:7.0"
type         = "LINUX_CONTAINER"
}

source {
type = "CODEPIPELINE"
}
}

