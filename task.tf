

resource "aws_ecs_task_definition" "CWRC-GitWriter" {
  family = "CWRC-GitWriter"
  container_definitions = file("CWRC-GitWriter.json")
  network_mode = "bridge"
  volume {
    name = "docker_sock"
    host_path = "/var/run/docker.sock"
  }
  volume {
    name = "traefik"
    host_path = "/awsconfig/traefik"
  }
  volume {
    name ="traefik_log" 
    host_path = "/awsconfig/traefik/log"
  }
  volume {
    name = "letsencrypt"
    host_path = "/awsconfig/letsencrypt"
  }
  volume {
    name = "cwrc-gitwriter"
    host_path = "/awsconfig/cwrc-gitwriter/config"
  }
  volume {
    name = "cwrc-gitserver"
    host_path = "/awsconfig/cwrc-gitserver/config"
  }
  volume {
    name = "validator"
    host_path = "/awsconfig/validator"
  }
  volume {
    name = "nerve"
    host_path = "/awsconfig/nerve"
  }







}
