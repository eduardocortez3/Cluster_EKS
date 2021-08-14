provider "kubernetes" {
  config_path    = "~/.kube/config"
}
resource "kubernetes_config_map" "aws-auth-cm" {
  metadata {
    name = "aws-auth"
  }

  data = {
    "my_config_file.yml" = "${file("${path.module}/manifests/aws-auth-cm.yaml")}"
  }
}

