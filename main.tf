# ─────────────────────────────────────────────
# 1. BLOQUE TERRAFORM Y PROVEEDOR
# ─────────────────────────────────────────────
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.1"
    }
  }
}

provider "aws" {
  region = "sa-east-1"
}

# ─────────────────────────────────────────────
# 2. RED — VPC Y SUBRED
# ─────────────────────────────────────────────
resource "aws_vpc" "agronorte_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "agronorte-vpc"
  }
}

resource "aws_subnet" "agronorte_subnet" {
  vpc_id                  = aws_vpc.agronorte_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "sa-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "agronorte-subnet"
  }
}

# ─────────────────────────────────────────────
# 3. INTERNET GATEWAY Y TABLA DE RUTAS
# ─────────────────────────────────────────────
resource "aws_internet_gateway" "agronorte_igw" {
  vpc_id = aws_vpc.agronorte_vpc.id
  tags = {
    Name = "agronorte-igw"
  }
}

resource "aws_route_table" "agronorte_rt" {
  vpc_id = aws_vpc.agronorte_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.agronorte_igw.id
  }
  tags = {
    Name = "agronorte-rt"
  }
}

resource "aws_route_table_association" "agronorte_rta" {
  subnet_id      = aws_subnet.agronorte_subnet.id
  route_table_id = aws_route_table.agronorte_rt.id
}

# ─────────────────────────────────────────────
# 4. INSTANCIA EC2
# ─────────────────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "agronorte_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.agronorte_subnet.id
  vpc_security_group_ids = [aws_security_group.agronorte_sg.id]
  key_name               = "agronorte-key"

  root_block_device {
    volume_size = 20
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io docker-compose
    systemctl start docker
    systemctl enable docker
  EOF

  tags = {
    Name = "agronorte-server"
  }
}

# ─────────────────────────────────────────────
# 5. IP ELASTICA
# ─────────────────────────────────────────────
resource "aws_eip" "agronorte_eip" {
  instance = aws_instance.agronorte_server.id
  domain   = "vpc"
}

# ─────────────────────────────────────────────
# 6. OUTPUTS
# ─────────────────────────────────────────────
output "ip_publica" {
  value       = aws_eip.agronorte_eip.public_ip
  description = "IP publica del servidor AgroNorte"
}