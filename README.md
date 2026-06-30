# AgroNorte ERP Cloud Infrastructure 

## Descripción

AgroNorte S.A. es una distribuidora de insumos agrícolas del NEA (Corrientes/Chaco) que operabaen papel y Excel, sin sistemas integrados, con silos de información entre sucursales.

Este proyecto implementa una transformación digital completa, mediante una infraestructura cloud con ERP, automatización de procesos y monitoreo continuo.


## Arquitectura del Sistema

- AWS Cloud región sa-east-1 São Paulo
- EC2 t3.micro con Ubuntu 22.04
- Docker con tres contenedores: Odoo 17, PostgreSQL 15 y n8n
- S3 Bucket para logs y backups
- CloudWatch para monitoreo y alarmas
- UptimeRobot para disponibilidad


## Tecnologías Utilizadas

| Terraform | Infraestructura como Código IaC | 
| AWS EC2 | Servidor cloud | 
| AWS S3 | Almacenamiento de logs y backups | 
| AWS CloudWatch | Monitoreo y alarmas | 
| Docker y Docker Compose | Contenerización de servicios | 
| PostgreSQL 15 | Base de datos relacional |
| Odoo 17 | ERP con CRM e Inventario | 
| n8n | Automatización de flujos de trabajo |
| UptimeRobot | Monitoreo de disponibilidad |

## Estructura del Repositorio

- main.tf — Recursos principales EC2, VPC, S3, CloudWatch
- security.tf — Security Groups y reglas de firewall
- docker-compose.yml — Orquestación de contenedores
- .gitignore — Archivos excluidos del repositorio


## Pasos para Desplegar

**Requisitos previos**
- AWS CLI configurado con credenciales
- Terraform instalado
- Par de claves SSH creado en AWS como agronorte-key

**1. Inicializar Terraform**
    terraform init

**2. Verificar el plan de infraestructura**
    terraform plan

**3. Aplicar y crear la infraestructura en AWS**
    terraform apply

**4. Conectarse al servidor por SSH**
    ssh -i agronorte-key.pem ubuntu@IP_PUBLICA

**5. Levantar los contenedores Docker**
    cd agronorte && sudo docker-compose up -d

**6. Acceder a los servicios**
- Odoo ERP: http://IP_PUBLICA:8069
- n8n Automatización: http://IP_PUBLICA:5678


## Módulos Implementados en Odoo

- **CRM** — Seguimiento de clientes y oportunidades de venta
- **Ventas** — Presupuestos y órdenes de venta
- **Inventario** — Control de stock de insumos agrícolas
- **Compras** — Órdenes de compra a proveedores


## Flujo de Automatización n8n

1. Schedule Trigger — se ejecuta diariamente
2. HTTP Request — obtiene datos de cliente desde fuente externa
3. Odoo Create Contact — crea el contacto en el CRM
4. Odoo Create Opportunity — genera oportunidad de venta automáticamente

##  Monitoreo Implementado

- **UptimeRobot** — verifica disponibilidad de Odoo cada 5 minutos y notifica por email si cae
- **CloudWatch** — alarma cuando CPU supera 80% o disco supera 85%
- **S3 Lifecycle** — logs con retención automática de 90 días
