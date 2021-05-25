variable ecs_ec2_image_id {
  type = string
  }
variable ecs_ec2_instance_type {
  type = string
  }
variable ecs_ec2_desired_capacity {
  type = number
  }
variable ecs_ec2_max_size {
  type = number
}
variable ecs_ec2_min_size {
  type = number
}
variable ecs_vpc {
  type = string
}
variable ecs_subnet_one_public {
  type = string
}
variable ecs_subnet_two_public {
  type = string
}
variable ecs_subnet_one_private {
  type = string
}
variable ecs_subnet_two_private {
  type = string
}
variable ecs_keypair {
  type = string
}

data "aws_iam_policy_document" "ecsInstanceRole" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_ssm_parameter" "imageid" {
  # (resource arguments)
  name = "imageid"
  type = "String"
  value = var.ecs_ec2_image_id 
}


resource "aws_iam_role" "ecsInstanceRole" {
  name               = "ecsInstanceRole"
  assume_role_policy = data.aws_iam_policy_document.ecsInstanceRole.json
}

resource "aws_iam_role_policy_attachment" "ecsInstanceRole" {
  role      = aws_iam_role.ecsInstanceRole.name
  for_each  = toset( ["arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role","arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"])
  policy_arn = each.key
}
/*
resource "aws_iam_role_policy_attachment" "ecsInstanceRole2" {
  role      = aws_iam_role.ecsInstanceRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
*/

resource "aws_iam_instance_profile" "ecsInstanceRole" {
  name = "ecsInstanceRole"
  role = aws_iam_role.ecsInstanceRole.name
}


resource "aws_launch_configuration" "EC2ContainerService-CWRC-GitWriter" {
  name = "ECS_EC2_GitWriter_LaunchConfig"
  image_id             = aws_ssm_parameter.imageid.value 
  iam_instance_profile = aws_iam_instance_profile.ecsInstanceRole.name
  security_groups      = [var.ecs_ec2_secgroup]
  user_data            = "#!/bin/bash\necho ECS_CLUSTER=CWRC-GitWriter >> /etc/ecs/ecs.config\nyum install unzip -y\ncurl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\"\nunzip -q awscliv2.zip\n./aws/install\n/usr/local/bin/aws s3 cp s3://s3-cwrc-config-data/ /awsconfig --recursive"
  instance_type        = var.ecs_ec2_instance_type
  key_name             = "cwrc-dev"
}

resource "aws_autoscaling_group" "EC2ContainerService-CWRC-GitWriter" {
  name                = "EC2ContainerService-CWRC-GitWriter"
  vpc_zone_identifier = [var.ecs_subnet_one_public, var.ecs_subnet_two_public]
  desired_capacity   = var.ecs_ec2_desired_capacity
  max_size           = var.ecs_ec2_max_size
  min_size           = var.ecs_ec2_min_size

  launch_configuration = aws_launch_configuration.EC2ContainerService-CWRC-GitWriter.name
  tags = concat( 
  [
    {
      "key" = "Name"
      "value" = "EC2ContainerService-CWRC-GitWriter"
      "propagate_at_launch" = true 
    },
    {
      "key" = "Owner"
      "value" = "SysOps"
      "propagate_at_launch" = true 
    },
    {
      "key" = "Application"
      "value" = "CWRC GitWriter"
      "propagate_at_launch" = true 
    },
    {
      "key" = "Department"
      "value" = "DPS"
      "propagate_at_launch" = true 
    },
    {
      "key" = "Environment"
      "value" = "dev"
      "propagate_at_launch" = true 
    },
    {
      "key" = "Purpose"
      "value" = "Academic"
      "propagate_at_launch" = true 
    },
    {
      "key" = "Terraform"
      "value" = "true"
      "propagate_at_launch" = false
    },
    {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
    }
  ]
  )
/*
  tags = {
    Name = "EC2ContainerService-CWRC-GitWriter"
    Owner           = "SysOps"
    Application     = "CWRC GitWriter"
    Department      = "DPS"
    Environment     = "dev"
    Purpose = "Academic"
    Terraform = "true"
  }
*/
  lifecycle {
    ignore_changes = [load_balancers, target_group_arns]
  }

}


resource "aws_ecs_cluster" "GitWriter" {
  name = "CWRC-GitWriter"
  tags = {
    Owner           = "SysOps"
    Application     = "CWRC GitWriter"
    Department      = "DPS"
    Environment     = "dev"
    Purpose         = "Academic"
    Terraform       = "true"
  }

}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "6.1.0"
  # insert the 4 required variables here
  name = "CWRC-GitWriter-ALB"
  load_balancer_type = "application"
  vpc_id             = var.ecs_vpc
  subnets = [var.ecs_subnet_one_public, var.ecs_subnet_two_public]
  security_groups = [var.ecs_ec2_secgroup]


target_groups = [
    {
      backend_protocol = "HTTPS"
      backend_port     = 443
      target_type      = "instance"
    }
  ]

https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = aws_acm_certificate.gitwriter-dev.arn
      target_group_index = 0
    }
]  

http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]


tags = {
    Owner           = "SysOps"
    Application     = "CWRC GitWriter"
    Department      = "DPS"
    Environment     = "dev"
    Purpose         = "Academic"
    Terraform       = "true"
  }

}
resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.EC2ContainerService-CWRC-GitWriter.id
  alb_target_group_arn = module.alb.target_group_arns[0]
}

resource "aws_ecs_service" "GitWriter" {
  name            = "GitWriter"
  cluster         = aws_ecs_cluster.GitWriter.id
  task_definition = aws_ecs_task_definition.CWRC-GitWriter.arn
  scheduling_strategy = "DAEMON"
}
