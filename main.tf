terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "tf_vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "tf_gw"
  }
}

resource "aws_eip" "elastic_ip" {
  vpc        = true
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "tf_eip"
  }
}

# NAT
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.elastic_ip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "ef_gw_NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

###############
#Subnets
###############
#Public
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "tf_subnet_public"
  }
}

#Private
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "tf_subnet_private"
  }
}

###############
#Route tables
###############

#Public

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "tf_public_rt"
  }
}


#Private

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "tf_private_rt"
  }
}


resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw.id
}

###############
#Route table associations
###############

#route table association public
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

#route table association public
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_network_interface" "public" {
  subnet_id = aws_subnet.public.id
  security_groups = [aws_security_group.sg.id]
  tags = {
    Name = "tf_public_network_interface"
  }
}

resource "aws_network_interface" "private" {
  subnet_id = aws_subnet.private.id
  security_groups = [aws_security_group.sg.id]
  tags = {
    Name = "tf_private_network_interface"
  }
}


resource "aws_instance" "public_instance" {
  ami                    = "ami-08d70e59c07c61a3a"
  instance_type          = "t2.micro"
  network_interface {
    network_interface_id = aws_network_interface.public.id
    device_index         = 0
  }

  tags = {
    Name = "public_instance"
  }
}

resource "aws_instance" "private_instance" {
  ami                    = "ami-08d70e59c07c61a3a"
  instance_type          = "t2.micro"
  network_interface {
    network_interface_id = aws_network_interface.private.id
    device_index         = 0
  }

  tags = {
    Name = "private_instance"
  }
}

resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    description = "worldwide"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    description = "worldwide"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
