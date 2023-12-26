terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ca-central-1"
}

resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "SIBI"
  }
}

resource "aws_subnet" "pubsub" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
 availability_zone = "ca-central-1a" 
  tags = {
    Name = "publicsub"
  }
}

resource "aws_subnet" "pvtsub" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
availability_zone = "ca-central-1b"
  tags = {
    Name = "privatesub"
  }
}

resource "aws_internet_gateway" "tigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "TIGW"
  }
}

resource "aws_route_table" "pubrt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tigw.id
  }
  tags = {
    Name = "publicrt"
  }
}

resource "aws_route_table_association" "pubass" {
  subnet_id      = aws_subnet.pubsub.id
  route_table_id = aws_route_table.pubrt.id
}

resource "aws_eip" "teip" {
  vpc      = true
}

resource "aws_nat_gateway" "tnat" {
  allocation_id = aws_eip.teip.id
  subnet_id     = aws_subnet.pubsub.id

  tags = {
    Name = "TNATGW"
  }
}

resource "aws_route_table" "pvtrt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.tnat.id
  }
  tags = {
    Name = "privatert"
  }
}

resource "aws_route_table_association" "pvtass" {
  subnet_id      = aws_subnet.pvtsub.id
  route_table_id = aws_route_table.pvtrt.id
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_all"
  }
}

resource "aws_instance" "public-machine" {
  ami           = "ami-03520d0f674d64df7"
  availability_zone = "ca-central-1a"
  instance_type = "t2.micro"
  tags = {
    Name = "sibipub"
  }
  key_name = "1213"
  vpc_security_group_ids= [aws_security_group.allow_all.id]
  subnet_id      = aws_subnet.pubsub.id
  associate_public_ip_address = true

}

resource "aws_instance" "private-machine" {
  ami           = "ami-06c3426233c180fef"
  availability_zone = "ca-central-1b"
  instance_type = "t2.micro"
  tags = {
    Name = "sibipvt"
  }
  key_name = "1213"
  vpc_security_group_ids= [aws_security_group.allow_all.id]
  subnet_id      = aws_subnet.pvtsub.id
  associate_public_ip_address = true

}
