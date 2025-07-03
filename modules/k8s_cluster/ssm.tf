resource "aws_ssm_parameter" "k8s_join_command" {
  name  = "/k8s/join"
  type  = "String"
  value = "placeholder"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "k8s_proxy_url" {
  name  = "/k8s/proxy-url"
  type  = "String"
  value = "http://127.0.0.1:8001"

  lifecycle {
    ignore_changes = [value]
  }
}
