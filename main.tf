terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.17.0"
    }
  }
}

provider "aws" {
    region = "us-east-2"
}

variable "instance_ids" {
  type    = list(string)
  default = ["ec2_instance1", "ec2_instance2"]  # Add more instance IDs as needed
}


variable "ami_id" {
    default = "ami-024e6efaf93d85776"
}

variable "instance_name1" {
    default = "TerraPublic"
}
variable "instance_name2" {
    default = "TerraPrivate"
}
variable "key_name" {
    default = "macohiokeypair"
}

variable "cidr" {
    default = "10.1.0.0/16"
}

variable "instance_type" {
    default = "t2.micro"
}

resource "aws_vpc" "myvpc" {
    cidr_block = var.cidr
}

resource "aws_subnet" "mysubnet1" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.1.1.0/24"
    availability_zone = "us-east-2a"
    map_public_ip_on_launch = true
}

resource "aws_subnet" "mysubnet2" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.1.2.0/24"
    availability_zone = "us-east-2b"
    map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "ig" {
    vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "rt1" {
    vpc_id = aws_vpc.myvpc.id
    tags = {
        Name = "MyPublicRouteTable"
    }
}

resource "aws_route" "route1" {
    route_table_id = aws_route_table.rt1.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
}

resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.mysubnet1.id
    route_table_id = aws_route_table.rt1.id
}

resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.mysubnet2.id
    route_table_id = aws_route_table.rt1.id
}

resource "aws_lb_target_group" "target" {
  name     = "my-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.target.arn
  target_id        = aws_instance.ec2_instance1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.target.arn
  target_id        = aws_instance.ec2_instance2.id
  port             = 80
}

resource "aws_lb" "lb" {
  name               = "my-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.websg.id]
  subnets            = [aws_subnet.mysubnet1.id, aws_subnet.mysubnet2.id]

#   enable_deletion_protection = true

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target.arn
  }
}

resource "aws_security_group" "websg" {
    vpc_id = aws_vpc.myvpc.id
    ingress {
    description = "HTTP from VPC"
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
  ingress {
    from_port   = 8080
    to_port     = 8080
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
    Name = "Web-sg"
  }
}

resource "aws_instance" "ec2_instance1" {
    ami = var.ami_id
    instance_type = var.instance_type
    vpc_security_group_ids = [aws_security_group.websg.id]
    availability_zone = "us-east-2a" 
    subnet_id = aws_subnet.mysubnet1.id
    user_data = base64encode(file("userdata.sh"))
    tags = {
        Name = var.instance_name1
    }
    key_name = var.key_name
}

resource "aws_instance" "ec2_instance2" {
    ami = var.ami_id
    instance_type = var.instance_type
    vpc_security_group_ids = [aws_security_group.websg.id]
    availability_zone = "us-east-2b" 
    subnet_id = aws_subnet.mysubnet2.id
    user_data = base64encode(file("userdata1.sh"))
    tags = {
        Name = var.instance_name2
    }
    key_name = var.key_name
}

output "public_ip1" {
    value = aws_instance.ec2_instance1.public_ip
}
output "public_ip2" {
    value = aws_instance.ec2_instance2.public_ip
}
output "subnet_id" {
    value = aws_subnet.mysubnet2.id
}
output "rt_id" {
    value = aws_route_table.rt1.id
}
output "dns" {
    value = aws_lb.lb.dns_name
}   