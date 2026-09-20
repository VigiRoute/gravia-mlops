# Réseau minimal : un VPC, un sous-réseau public (serving, exposé), un sous-réseau privé
# (base de données, pas d'accès direct depuis l'extérieur) — suffisant pour démontrer la
# ségrégation réseau attendue (cf. Architecture_GRAVIA.md §7, "moindre privilège"), pas un
# design multi-AZ de production réelle (hors de portée de la démo, cf.
# docs/Deploiement_GRAVIA_MLOps.md).
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "gravia-${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "gravia-${var.environment}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 0)
  map_public_ip_on_launch = true

  tags = {
    Name = "gravia-${var.environment}-subnet-public"
  }
}

# Deux sous-réseaux privés dans deux zones de disponibilité différentes : exigence AWS pour un
# groupe de sous-réseaux RDS (aws_db_subnet_group, cf. module storage), même si un seul suffirait
# fonctionnellement pour cette démo — écrit correct pour la cible AWS réelle (cf.
# `var.include_pro_only_services`), pas seulement pour ce qui est applicable sur LocalStack.
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "gravia-${var.environment}-subnet-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "gravia-${var.environment}-subnet-private-b"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "gravia-${var.environment}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Serving (public) : HTTPS entrant depuis l'extérieur, tout sortant.
resource "aws_security_group" "serving" {
  name        = "gravia-${var.environment}-sg-serving"
  description = "API de prédiction — HTTPS entrant, tout sortant"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "gravia-${var.environment}-sg-serving"
  }
}

# Base de données (privé) : accessible uniquement depuis le groupe serving, pas depuis Internet
# (cf. Architecture_GRAVIA.md §7, moindre privilège).
resource "aws_security_group" "database" {
  name        = "gravia-${var.environment}-sg-database"
  description = "PostgreSQL — accessible uniquement depuis le serving"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.serving.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gravia-${var.environment}-sg-database"
  }
}
