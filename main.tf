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
# 3.5. IAM ROLE PARA CLOUDWATCH AGENT
# ─────────────────────────────────────────────
resource "aws_iam_role" "cloudwatch_agent_role" {
  name = "agronorte-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cloudwatch_agent_profile" {
  name = "agronorte-cloudwatch-profile"
  role = aws_iam_role.cloudwatch_agent_role.name
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
  iam_instance_profile = aws_iam_instance_profile.cloudwatch_agent_profile.name

  root_block_device {
    volume_size = 20
  }

  user_data = <<-EOF
  #!/bin/bash
  apt-get update -y
  apt-get install -y docker.io docker-compose

  systemctl start docker
  systemctl enable docker

  # Instalar CloudWatch Agent
  wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
  dpkg -i -E ./amazon-cloudwatch-agent.deb

  # Configuración: qué métricas mandar (en este caso, uso de disco)
  cat <<'CONFIG' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  {
    "metrics": {
      "namespace": "CWAgent",
      "metrics_collected": {
        "disk": {
          "measurement": ["disk_used_percent"],
          "resources": ["/"]
        }
      }
    }
  }
  CONFIG

  # Arrancar el agente con esa configuración
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
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

# ─────────────────────────────────────────────
# 7. S3 BUCKET — LOGS Y BACKUPS
# ─────────────────────────────────────────────
resource "aws_s3_bucket" "agronorte_logs" {
  bucket = "agronorte-logs-backups-2026"
  tags = {
    Name = "agronorte-logs"
  }
}

resource "aws_s3_bucket_versioning" "agronorte_logs_versioning" {
  bucket = aws_s3_bucket.agronorte_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "agronorte_logs_lifecycle" {
  bucket = aws_s3_bucket.agronorte_logs.id
  rule {
    id     = "eliminar-logs-viejos"
    status = "Enabled"

 filter {} 

    expiration {
      days = 90
    }
  }
}

# ─────────────────────────────────────────────
# 8. CLOUDWATCH — MONITOREO DE LA INSTANCIA
# ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "cpu_alto" {
  alarm_name          = "agronorte-cpu-alto"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alerta cuando CPU supera 80% por 4 minutos"
  dimensions = {
    InstanceId = aws_instance.agronorte_server.id
  }
  alarm_actions = [aws_sns_topic.agronorte_alertas.arn]  
}
resource "aws_cloudwatch_metric_alarm" "memoria_alta" {
  alarm_name          = "agronorte-disco-alto"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 120
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Alerta cuando disco supera 85%"
  dimensions = {
    device = "nvme0n1p1"
    fstype = "ext4"
    host   = "ip-10-0-1-173"
    path   = "/"
  }
  alarm_actions = [aws_sns_topic.agronorte_alertas.arn]
}
# ─────────────────────────────────────────────
# 9. SNS — NOTIFICACIONES DE ALARMAS
# ─────────────────────────────────────────────
resource "aws_sns_topic" "agronorte_alertas" {
  name = "agronorte-alertas"
}

resource "aws_sns_topic_subscription" "agronorte_email_alerta" {
  topic_arn = aws_sns_topic.agronorte_alertas.arn
  protocol  = "email"
  endpoint  = "valentinasalmon11@gmail.com"  
}