# ─────────────────────────────────────────────
# FIREWALL — SECURITY GROUP
# ─────────────────────────────────────────────
resource "aws_security_group" "agronorte_sg" {
  name        = "agronorte-sg"
  description = "Reglas de acceso para AgroNorte"
  vpc_id      = aws_vpc.agronorte_vpc.id

  # SSH — administracion del servidor
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Odoo — ERP
  ingress {
    from_port   = 8069
    to_port     = 8069
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # n8n — automatizacion
  ingress {
    from_port   = 5678
    to_port     = 5678
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
# Moodle - LMS
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Salida — todo permitido
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "agronorte-sg"
  }
}