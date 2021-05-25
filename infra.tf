variable allowed_cidr {
  type = list(string)
  }
variable ssh_access {
  type = list(string)
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "ecs_ec2_secgroup2" {
  name         ="ecs_ec2_secgroup2"
  description  = "allow standard http and https inbound and everything outbound"
  vpc_id      = var.ecs_vpc
  
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = var.allowed_cidr
  }
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = var.allowed_cidr
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = var.ssh_access
  } 
  egress  {
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name            = "ecs_ec2_secgroup"
    Owner           = "SysOps"
    Application     = "CWRC 2.0"
    Department      = "DPS"
    Environment     = "dev"
    Functional_Area = "Academic"
    "Terraform" : "true"
  }

}


resource "aws_s3_bucket" "CWRC_GitWriter_config_data" {
  bucket = "s3-cwrc-config-data"
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = ""
        sse_algorithm     = "AES256"
      }
    }
  }
  tags = {
    Name            = "s3-GitWriter_config_data"
    Owner           = "SysOps"
    Application     = "CWRC GitWriter"
    Department      = "DPS"
    Environment     = "dev"
    Functional_Area = "Academic"
    "Terraform" : "true"
  }
}


resource "aws_acm_certificate" "cwrc-dev" {
  private_key=file("cwrc-dev.key")
  certificate_body = file("cwrc-dev.pem")
  certificate_chain=file("cwrc-dev_interm.cer")
}
