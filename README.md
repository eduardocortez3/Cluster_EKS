## Deploy cluster AWS EKS com 3 nodes e

### Requisitos:

`aws cli` : https://docs.aws.amazon.com/pt_br/cli/latest/userguide/cli-chap-install.html

`Credenciais de acesso:` https://docs.aws.amazon.com/pt_br/cli/latest/userguide/cli-chap-configure.html

`Kubectl` : https://kubernetes.io/docs/tasks/tools/

`Terraform:`  https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/aws-get-started

`Helm:`  [Using Helm with Amazon EKS - Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/helm.html)





---

### Deploy:

**Observações iniciais:**

- A documentação seguida para criação: https://docs.aws.amazon.com/pt_br/cli/latest/userguide/install-linux.html
- A ideia desse deploy  é fazer o mais simples e rápido possível.
- A sua key pairs do AWS tem que ser alterada no arquivo `var.tf`
- As características do cluster podem ser facilmente alteradas antes do deploy através do arquivo `var.tf`

```yaml
variable "vpc" {
    type = map
    description = "Nome do Stack que aparece no Cloudformation Stack"
    default = {
       "vpc_name" = "VPC-EKS"
   }
}

variable "role" {
    type = map
    description = "Nome Role que será criada no IAM para o cluster e nodes"
    default = {
        "eks_name"       = "eks-role"
        "node_role_name" = "eks-node-group"
    }
}

variable "eks" {
  type = map
  description = "Nome e chave de acesso ao cluster EKS"
  default = {
        "name"    = "eks01"
        "ssh_key" = "terraform-aws"
  }
}

variable "nodegroup" {
  type = map
  description = "Características do Node Group"
  default = {
        "name"    = "nodegroup_eks"
        "ami"     = "AL2_x86_64"
        "type"    = "t3.small"
        "min"     = "1"
        "max"     = "6"
        "desired" = "4"
        "disk"    = "20"
  }
}


```



### Criando a VPC

Primeiro temos que criar a VPC e a AWS nos fornece no procedimento uma template para isso. Utilizaremos a recomendada ( Public and private subnets ).  Serão criadas  4 subnets em 2 Availability Zones serapadas conforme explica a imagem abaixo:

doc ref: [Creating a VPC for your Amazon EKS cluster - Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/create-public-private-vpc.html)



Detalhes do que é feito:

![](/home/stark/.var/app/com.github.marktext.marktext/config/marktext/images/2021-08-13-15-24-45-image.png)

O terraform precisa das subnet_ids para realizar o deploy do restante do ambiente, a forma mais simples que encontrei para fazer isso foi com o `for_each` , então precisamos primeiro executar a criação da VPC separado: 



- dentro do diretório projeto_eks  Execute:

        `terraform init`

        `terraform apply -target=aws_cloudformation_stack.vpc`



- Após o deploy da VPC,  realizaremos o deploy de todo o resto do ambiente:

       `terraform apply`



> Caso não queira perder as configurações atuais do /home/$USER/.kube/config salve antes de executar o comando abaixo.



No final da execução será exibido algumas informações como: Nome do cluster criado, subnets, e o kubeconfig-certificate que você pode inserir no arquivo `/home/$USER/.kube/config`  ou pode somente executar o comando abaixo:



     `aws eks update-kubeconfig --name  NOME DO CLUSTER AQUI`



O cluster está pronto com os add-ons: `kube-proxy` e  `vpc-cni` 

Configuração de logging API Server, Audit, Controller manager e Scheduler  direcionada para o Cloud Watch.



### Monitoração

Na etapa anterior foi criado o serviço do EKS e os nodes. Agora vamos juntar tudo e criar o painel de monitoração:



Acesse o diretório eks e lá dentro digite:

`terraform init`

`terraform apply`



depois que concluir o deploy execute os seguintes comandos:

`kubectl apply -f eks/manifests/components.yaml`

`kubectl apply -f eks/manifests/calico-operator.yaml`

`kubectl apply -f eks/manifests/calico-crs.yaml`



Pronto ! 



O que foi feito deploy no cluster:

- Prometheus - https://github.com/prometheus-community

- Grafana  - https://github.com/grafana

- Calico - https://docs.aws.amazon.com/pt_br/eks/latest/userguide/calico.html

- Metrics  - https://docs.aws.amazon.com/pt_br/eks/latest/userguide/metrics-server.html
  
  



O painel do grafana pode ser acessado :

         usuário:  admin

         senha:  prom-operator



Temos lá dentro um painel do granafa como mostro abaixo algumas telas de monitoração de vários recursos:



![](/media/stark/DATA/aws/Projetos/projeto_desafio/images/monitor_network_grafana_01.png)

![](/media/stark/DATA/aws/Projetos/projeto_desafio/images/monitor_network_grafana_02.png)

![](/media/stark/DATA/aws/Projetos/projeto_desafio/images/monitor_network_grafana_03.png)

![](/media/stark/DATA/aws/Projetos/projeto_desafio/images/monitor_network_grafana_04..png)



Lista da maioria dos dashboards prontos com dados do Prometheus

![](/media/stark/DATA/aws/Projetos/projeto_desafio/images/dashboards.png)

---

### Explicando principais pontos do código:

Arquivo `main.tf`

```yaml
################ DEPLOY DO VPC ################
resource "aws_cloudformation_stack" "vpc" {
  name = var.vpc.vpc_name
  parameters = {
  }
    template_body = file("${path.module}/amazon-eks-vpc-private-subnets.yaml")
}
data "aws_subnet_ids" "subnets_ids" {
  vpc_id = aws_cloudformation_stack.vpc.outputs.VpcId
  depends_on = [
    aws_cloudformation_stack.vpc,  
  ]
}
data "aws_subnet" "names_subnets" {
  for_each = data.aws_subnet_ids.subnets_ids.ids
  id       = each.value
  depends_on = [
    aws_cloudformation_stack.vpc,
    data.aws_subnet_ids.subnets_ids,
  ]
}
```

- Aqui fazemos o deploy do VPC utilizando a template da aws e depois uso o `data aws_subnet` para pegar o valor das ids das subnets que precisaremos utilizar nas próximas etapas. Utilizo o for_each para fazer isso e por isso precisamos fazer como primeira etapa antes do deploy de topa aplicação.

*    Obs.: O formato das variáveis existentes no `terraform.tfstate`  não entregam corretamente valor das ids que precisamo.*

```yaml
resource "aws_eks_cluster" "eks" {
  name     = var.eks.name
  enabled_cluster_log_types = ["api", "audit", "controllerManager", "scheduler"]
  role_arn = aws_iam_role.eks_role.arn
  version = "1.21"
 
  vpc_config {
    subnet_ids = data.aws_subnet_ids.subnets_ids.ids
  }
  depends_on = [
    aws_cloudformation_stack.vpc,
    aws_iam_role.eks_role,
    aws_iam_policy_attachment.eks_role-AmazonEKSClusterPolicy,
    aws_iam_policy_attachment.eks_role-AmazonEKSServicePolicy,
  ]
}
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "vpc-cni"
  depends_on = [
    aws_eks_cluster.eks    
  ]
}
resource "aws_eks_addon" "kubeproxy" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "kube-proxy"
  depends_on = [
    aws_eks_cluster.eks,
    aws_eks_addon.vpc_cni
  ]
}
resource "aws_cloudwatch_log_group" "role_logging_eks" {
  name              = "/aws/eks/${var.eks.name}"
  retention_in_days = 7
}
```

- Nessa segunda etapa crio o cluster EKS e adiciono alguns addons e habilito o log, tudo isso para para gerar algumas métricas.  Por conta de organização eu separei as roles e políticas no arquivo `iam.tf`
  
  *Obs.: O coredns algumas vezes apresenta problemas para habilitar no EKS via terraform, por conta disso achei melhor não habilitar. Pode ser habilitado manualmente.*
  
  



```yaml

################ DEPLOY NODES DO EKS ################
resource "aws_eks_node_group" "nodegroup_eks" {
  cluster_name    = var.eks.name
  node_group_name = var.nodegroup.name
  node_role_arn   = "${aws_iam_role.eks_role_nodes.arn}"
  subnet_ids      = "${data.aws_subnet_ids.subnets_ids.ids}"
  ami_type        = "${var.nodegroup.ami}"
  disk_size       = "${var.nodegroup.disk}"
  instance_types  = ["${var.nodegroup.type}"]

remote_access {
  ec2_ssh_key = var.eks.ssh_key
}
  scaling_config {
    desired_size = "${var.nodegroup.desired}"
    max_size     = "${var.nodegroup.max}"
    min_size     = "${var.nodegroup.min}"
  }
  depends_on = [
    aws_iam_role.eks_role,
    aws_cloudformation_stack.vpc,
    aws_eks_cluster.eks,
    aws_iam_role_policy_attachment.eks_role_nodes-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_role_nodes-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_role_nodes-AmazonEC2ContainerRegistryReadOnly,
    
  ]
}
```

- Na terceira etapa do `main.tf` crio o nodegroup com as configurações determinadas no aquivo `'var.tf` .  Por conta de organização eu separei as roles e políticas no arquivo `iam.tf`
  
  

Achei melhor separar o deploy em 2 partes então a segunda parte é configuração baseada em kubectl e helm.



```yaml

resource "kubernetes_config_map" "aws-auth-cm" {
  metadata {
    name = "aws-auth"
  }

  data = {
    "my_config_file.yml" = "${file("${path.module}/manifests/aws-auth-cm.yaml")}"
  }
}

```

- Faço aqui o deploy do configmap com o arn do nodegroup criado na etapa anterior.

```yaml
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts/"
  chart      = "kube-prometheus-stack"

  depends_on = [
    kubernetes_config_map.aws-auth-cm
  ]
}
```

- Faço a instalação do prometheus e grafana utilizando o helm

- 
