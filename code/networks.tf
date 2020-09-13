## Master VPC for Jenkins master node.
resource "aws_vpc" "vpc_master" {
  provider             = aws.region-master
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "master-vpc-jenkins"
  }
}

## Worker VPC for Jenkins worker node.
resource "aws_vpc" "vpc_worker_oregon" {
  provider             = aws.region-worker
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "worker-vpc-jenkins"
  }
}

##Initiating Peering connection from master vpc
resource "aws_vpc_peering_connection" "master-workervpc" {
  provider    = aws.region-master
  peer_vpc_id = aws_vpc.vpc_worker_oregon.id
  vpc_id      = aws_vpc.vpc_master.id
  peer_region = var.region-worker
}

##Accept peering connection
resource "aws_vpc_peering_connection_accepter" "accept_peering" {
  provider                  = aws.region-worker
  vpc_peering_connection_id = aws_vpc_peering_connection.master-workervpc.id
  ##We can auto accept peering connection here if account is same.
  auto_accept = true
}

## Create Interner Gateway for master vpc
resource "aws_internet_gateway" "igw-mastervpc" {
  provider = aws.region-master
  vpc_id   = aws_vpc.vpc_master.id
}

## Create Interner Gateway for worker vpc
resource "aws_internet_gateway" "igw-workervpc" {
  provider = aws.region-worker
  vpc_id   = aws_vpc.vpc_worker_oregon.id
}

## Create route table in master vpc
resource "aws_route_table" "internet_route_master" {
  provider = aws.region-master
  vpc_id   = aws_vpc.vpc_master.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-mastervpc.id
  }
  route {
    cidr_block                = "192.168.1.0/24"
    vpc_peering_connection_id = aws_vpc_peering_connection.master-workervpc.id
  }
  lifecycle {
    ignore_changes = all
  }
  tags = {
    Name = "Master-Region-RT"
  }
}

## Overwrite default route table of VPC master
resource "aws_main_route_table_association" "set-mastervpc-rt" {
  provider       = aws.region-master
  vpc_id         = aws_vpc.vpc_master.id
  route_table_id = aws_route_table.internet_route_master.id
}

## Create route table in worker vpc
resource "aws_route_table" "internet_route_worker" {
  provider = aws.region-worker
  vpc_id   = aws_vpc.vpc_worker_oregon.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-workervpc.id
  }
  route {
    cidr_block                = "10.0.1.0/24"
    vpc_peering_connection_id = aws_vpc_peering_connection.master-workervpc.id
  }
  lifecycle {
    ignore_changes = all
  }
  tags = {
    Name = "Worker-Region-RT"
  }
}

## Overwrite default route table of VPC master
resource "aws_main_route_table_association" "set-workervpc-rt" {
  provider       = aws.region-worker
  vpc_id         = aws_vpc.vpc_worker_oregon.id
  route_table_id = aws_route_table.internet_route_worker.id
}


## Get all the AZs list for Master VPC
data "aws_availability_zones" "azs" {
  provider = aws.region-master
  state    = "available"
}

## Create Subnet #1 in Master VPC
resource "aws_subnet" "subnet_master1" {
  provider          = aws.region-master
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
  vpc_id            = aws_vpc.vpc_master.id
  cidr_block        = "10.0.1.0/24"
}

## Create Subnet #2 in Master VPC
resource "aws_subnet" "subnet_master2" {
  provider          = aws.region-master
  availability_zone = element(data.aws_availability_zones.azs.names, 1)
  vpc_id            = aws_vpc.vpc_master.id
  cidr_block        = "10.0.2.0/24"
}

## Create Subnet #1 in Worker VPC
resource "aws_subnet" "subnet_worker1" {
  provider   = aws.region-worker
  vpc_id     = aws_vpc.vpc_worker_oregon.id
  cidr_block = "192.168.1.0/24"
}

##Create SG for LB, only TCP/80,TCP/443 and ongoing access
resource "aws_security_group" "lb-sg" {
  provider    = aws.region-master
  name        = "lb-sg"
  description = "Allow 443 and traffic to Jenkins SG"
  vpc_id      = aws_vpc.vpc_master.id
  ingress {
    description = "Allow 443 from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow 80 from anywhere for redirection"
    from_port   = 80
    to_port     = 80
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


## Create SG for allowing TCP/8080 from * and TCP/22 from External IP in master VPC
resource "aws_security_group" "jenkins-sg" {
  provider    = aws.region-master
  name        = "jenkins-sg"
  description = "Allow TCP/${var.webserver-port} & TCP/22"
  vpc_id      = aws_vpc.vpc_master.id
  ingress {
    description = "Allow 22 from our public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.external-ip]
  }
  ingress {
    description     = "allow traffic from LB on port ${var.webserver-port}"
    from_port       = var.webserver-port
    to_port         = var.webserver-port
    protocol        = "tcp"
    security_groups = [aws_security_group.lb-sg.id]
  }
  ingress {
    description = "allow traffic from us-west-2"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.1.0/24"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##Create SG for allowing TCP/22 from your IP in Worker VPC
resource "aws_security_group" "jenkins-sg-worker" {
  provider    = aws.region-worker
  name        = "jenkins-sg-oregon"
  description = "Allow Master VPC & TCP/22"
  vpc_id      = aws_vpc.vpc_worker_oregon.id
  ingress {
    description = "Allow 22 from our public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.external-ip]
  }
  ingress {
    description = "Allow traffic from Master VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.1.0/24"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
