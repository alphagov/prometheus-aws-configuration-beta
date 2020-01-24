resource "aws_service_discovery_private_dns_namespace" "observe" {
  name        = "local.gds-reliability.engineering"
  description = "Observe instances"
  vpc         = data.terraform_remote_state.infra_networking.outputs.vpc_id
}

resource "aws_service_discovery_service" "alertmanager" {
  name = "alertmanager"

  description = "A service to allow alertmanager peers to discover each other"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.observe.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 2
  }
}

