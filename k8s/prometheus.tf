provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}


resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts/"
  chart      = "kube-prometheus-stack"

  depends_on = [
    kubernetes_config_map.aws-auth-cm
  ]

}
