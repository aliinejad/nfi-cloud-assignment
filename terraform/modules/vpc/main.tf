resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "SecureVPC"
  }
}

#########################
# SUBNETS
#########################

# Public subnets per AZ
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zones[count.index]

  tags = {
    Name = "PublicSubnet-${var.availability_zones[count.index]}"
  }
}

# Private subnets per AZ
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "PrivateSubnet-${var.availability_zones[count.index]}"
  }
}

#########################
# INTERNET GATEWAY
#########################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "VPC-IGW"
  }
}

#########################
# NAT GATEWAY & EIP
#########################

# Elastic IP per AZ for the NAT Gateway
resource "aws_eip" "nat_eip" {
  count = length(var.availability_zones)
  vpc   = true

  tags = {
    Name = "NAT-EIP-${var.availability_zones[count.index]}"
  }
}

# NAT Gateway per AZ
resource "aws_nat_gateway" "nat" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "VPC-NAT-Gateway-${var.availability_zones[count.index]}"
  }

  depends_on = [aws_internet_gateway.igw]
}

#########################
# ROUTE TABLES & ASSOCIATIONS
#########################

# Public Route Table (shared by all public subnets)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Associate each public subnet with the public route table
resource "aws_route_table_association" "public_assoc" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Tables (one per AZ)
resource "aws_route_table" "private_rt" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "PrivateRouteTable-${var.availability_zones[count.index]}"
  }
}

# Associate each private subnet with its corresponding private route table
resource "aws_route_table_association" "private_assoc" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt[count.index].id
}