# devopsproject-ecommerce-iac

Repositório de Infraestrutura como Código (IaC) do **Ecommerce DevOps Project**.

Contém **6 stacks Terraform independentes** e um conjunto de **roles Ansible** (~20 roles) que juntos provisionam e configuram toda a plataforma AWS: rede, cluster Kubernetes self-managed, camada de dados e mensageria, CI/CD keyless, frontend/CDN e observabilidade.

Cada stack tem seu próprio arquivo de state remoto em S3 (`devopsproject-terraform-state-files`) com locking via DynamoDB. Os outputs de cada stack são os contratos consumidos pelas stacks seguintes via `terraform_remote_state`.

> **Referência**: [ADR-0001](../docs/ADR-0001-rede-base-e-backend-de-estado.md) a [ADR-0007](../docs/ADR-0007-observabilidade.md) documentam as decisões arquiteturais de cada stack.

---

## Estrutura

```
devopsproject-ecommerce-iac/
├── terraform/
│   ├── backend/                    # Stack 1 — S3 + DynamoDB (state remoto do Terraform)
│   │   ├── s3.bucket.tf
│   │   ├── s3.bucket.security.tf
│   │   ├── dynamodb.table.tf
│   │   ├── variables.tf / outputs.tf / versions.tf / tags.tf / main.tf
│   │   └── envs/production.tfvars
│   ├── networking/                 # Stack 2 — VPC, subnets, NATs, Route53
│   │   ├── vpc.tf
│   │   ├── vpc.public-subnets.tf / vpc.private-subnets.tf
│   │   ├── vpc.public-route-table.tf / vpc.private-route-tables.tf
│   │   ├── vpc.nat-gateways.tf
│   │   ├── route53.tf
│   │   ├── variables.tf / outputs.tf / versions.tf / tags.tf / main.tf
│   │   └── envs/production.tfvars
│   ├── server/                     # Stack 3 — Cluster K8s (EC2, ASGs, NLB, SGs, ECR, ACM, SSM)
│   │   ├── ec2.instances.control-plane.tf / ec2.instances.worker.tf
│   │   ├── ec2.security-groups.*.tf / ec2.key-pair.tf
│   │   ├── nlb.tf / nlb.target-group.tf / nlb.listener.tf
│   │   ├── iam.control-plane.tf / iam.worker.tf
│   │   ├── acm.tf / ecr.tf
│   │   ├── ssm.association.tf / ssm.patch-baseline.tf / ssm.patch-group.tf
│   │   ├── autoscaling.lifecycle-hook.tf / sqs.node-termination.tf
│   │   ├── modules/ec2/            # Módulo reutilizável (instanciado para CP e workers)
│   │   ├── variables.tf / outputs.tf / versions.tf / tags.tf / main.tf
│   │   └── envs/production.tfvars
│   ├── serverless/                 # Stack 4 — Aurora, RDS Proxy, DocumentDB, SQS, SNS, Lambda, SES
│   │   ├── rds.cluster.tf / rds.cluster-instances.tf
│   │   ├── rds.proxy.tf / rds.proxy-endpoint.tf / rds.subnet-group.tf
│   │   ├── docdb.cluster.tf / docdb.cluster-instance.tf / docdb.*.tf
│   │   ├── sqs.queues.tf / sns.topic.tf / sns.subscriptions.tf
│   │   ├── lambda.order-confirmed.tf / lambda.report-job.tf
│   │   ├── lambda.layer.tf / lambda.iam.tf
│   │   ├── scheduler.report-job.tf / ses.*.tf
│   │   ├── secrets.documentdb.tf / security-groups.*.tf
│   │   ├── variables.tf / outputs.tf / versions.tf / tags.tf / main.tf
│   │   └── envs/production.tfvars
│   ├── site/                       # Stack 5 — CloudFront, S3, WAF + OIDC (GitHub Actions)
│   │   ├── s3.site.tf / s3.staging.tf / s3.site-logs.tf / s3.staging-logs.tf
│   │   ├── cloudfront.production.tf / cloudfront.staging.tf
│   │   ├── cloudfront.continuous-deployment.tf
│   │   ├── cloudfront.oac.tf / cloudfront.vpc-origin.tf
│   │   ├── waf.web-acl.tf
│   │   ├── iam.oidc-provider.tf
│   │   ├── iam.github-backend-role.tf / iam.github-frontend-role.tf
│   │   ├── route53.site.tf
│   │   ├── variables.tf / outputs.tf / versions.tf / tags.tf / main.tf
│   │   └── envs/production.tfvars
│   └── observability/              # Stack 6 — OpenSearch (logs + métricas)
│       ├── opensearch.domain.tf / opensearch.access-policy.tf
│       ├── opensearch.roles-mapping.tf / opensearch.audit-log-group.tf
│       ├── iam.fluentbit-write.tf
│       ├── variables.tf / outputs.tf / versions.tf / tags.tf / main.tf
│       └── envs/production.tfvars
└── ansible/
    ├── site.yml                    # Playbook principal (execução sequencial das roles)
    ├── production.aws_ec2.yml      # Inventário dinâmico via tags EC2
    ├── ansible.cfg
    └── group_vars/                 # Variáveis por grupo (all, control_plane, workers)
        └── roles/                  # ~20 roles executadas na ordem do site.yml
            ├── dependency-packages/
            ├── container-runtime/   # CRI-O
            ├── kube-packages/       # kubeadm + kubelet + kubectl v1.30
            ├── init-cluster/        # kubeadm init (primeiro CP)
            ├── container-network/   # Antrea CNI
            ├── container-storage/   # EBS CSI Driver (Helm)
            ├── join-workers/
            ├── join-control-planes/
            ├── helm/
            ├── cloud-controller/    # AWS Cloud Controller Manager
            ├── load-balancer-controller/  # AWS Load Balancer Controller
            ├── external-dns/
            ├── cluster-autoscaler/
            ├── metrics-server/
            ├── node-termination/    # Node Termination Handler
            ├── fluent-bit/          # Coleta de logs → OpenSearch (SigV4)
            └── metricbeat/          # Coleta de métricas → OpenSearch
```

---

## Pré-requisitos

Antes de iniciar o provisionamento, confirmar:

| Pré-requisito | Verificação |
|---|---|
| AWS CLI configurado com acesso à conta `692430448478` | `aws sts get-caller-identity` |
| IAM Role `terraform-role` criada na conta | `aws iam get-role --role-name terraform-role` |
| Domínio `ecommerce.devopsproject.com.br` registrado (Hostgator) | Acesso ao painel do registrador |
| Terraform `>= 1.10` instalado | `terraform version` |
| Ansible `>= 2.14` instalado | `ansible --version` |
| AWS Session Manager Plugin instalado (conexão Ansible via SSM) | `session-manager-plugin --version` |

---

## Ordem de Execução

As stacks têm dependências explícitas de outputs. **Respeitar esta ordem é obrigatório**.

```
backend  →  networking  →  server  →  serverless  →  site  →  observability
                               ↓
                           [Ansible]
```

> Para destruir, seguir a **ordem inversa**: observability → site → serverless → server (+ Ansible drain) → networking → backend.

---

## Stack 1 — backend

Bootstrap do estado remoto. Aplicada **uma única vez** com state local — o bucket S3 não pode guardar o próprio state antes de existir.

```bash
cd terraform/backend
terraform init
terraform apply -var-file="envs/production.tfvars"
```

> Após este apply, todas as stacks seguintes usam `backend "s3"` apontando para `devopsproject-terraform-state-files`.

**Recursos criados:** S3 bucket (versionado, SSE AES-256, public access block) + DynamoDB table (PAY_PER_REQUEST, hash key `LockID`).

---

## Stack 2 — networking

Fundação de rede. Consome o backend criado na Stack 1.

```bash
cd terraform/networking
terraform init
terraform apply -var-file="envs/production.tfvars"
```

**Recursos criados:** VPC `10.0.0.0/24`, 2 subnets públicas + 2 subnets privadas (us-east-1a / us-east-1b), Internet Gateway, 2 NAT Gateways (1 por AZ), route tables, Hosted Zone Route53.

**Após o apply — passo manual obrigatório:**

```bash
# Obter os Name Servers da Hosted Zone criada
terraform output route53_name_servers

# Configurar esses NSs no registrador externo (Hostgator)
# A propagação pode levar até 48h — verificar com:
dig NS ecommerce.devopsproject.com.br
```

> O ACM (Stack 3) só consegue validar os certificados TLS após a delegação DNS estar ativa.

**Outputs (contratos para stacks seguintes):** `vpc_id`, `private_subnets_ids`, `public_subnets_ids`, `route53_zone_id`.

---

## Stack 3 — server

Cluster Kubernetes self-managed. Depende dos outputs da Stack 2.

```bash
cd terraform/server
terraform init
terraform apply -var-file="envs/production.tfvars"
```

**Recursos criados:** Launch Templates (Debian 12, IMDSv2), ASG control plane (2×t3.medium) + ASG workers (4–5×t3.micro), NLB interno TCP 6443, Security Groups (CP, workers, ALB), IAM roles + instance profiles, ACM wildcard, 6 repositórios ECR, SSM Patch Manager.

**Outputs:** `nlb_dns_name`, `acm_certificate_arn`, `control_plane_security_group_id`, `worker_security_group_id`, `ecr_repository_urls`.

### Bootstrap do cluster com Ansible

Após o Terraform criar as instâncias, executar o playbook Ansible para inicializar o Kubernetes:

```bash
cd ansible/

# Verificar que o inventário dinâmico detecta as instâncias (aguardar ~3 min após o apply)
ansible-inventory -i production.aws_ec2.yml --list

# Executar o playbook completo
ansible-playbook -i production.aws_ec2.yml site.yml
```

O `site.yml` executa as roles na seguinte ordem:
1. `dependency-packages` — todos os nodes
2. `container-runtime` (CRI-O) — todos os nodes
3. `kube-packages` (kubeadm/kubelet/kubectl v1.30) — todos os nodes
4. `init-cluster` (kubeadm init) — primeiro control plane
5. `container-network` (Antrea CNI) — primeiro control plane
6. `container-storage` (EBS CSI) — primeiro control plane
7. `join-workers` — workers
8. `join-control-planes` — control planes adicionais
9. `helm` — primeiro control plane
10. `cloud-controller`, `load-balancer-controller`, `external-dns` — controllers AWS
11. `cluster-autoscaler`, `metrics-server`, `node-termination`

```bash
# Validar o cluster após o playbook
kubectl get nodes
kubectl get pods -n kube-system
```

---

## Stack 4 — serverless

Camada de dados e mensageria. Depende dos Security Groups da Stack 3 (consumidos via `data source`).

```bash
cd terraform/serverless
terraform init
terraform apply -var-file="envs/production.tfvars"
```

**Recursos criados:** Aurora PostgreSQL Serverless v2 (2 instâncias multi-AZ) + RDS Proxy (pooling + endpoint read-only), DocumentDB (TLS, audit), 3 filas SQS + 3 DLQs, SNS `OrderConfirmedTopic`, Lambda `order-confirmed` + `report-job` + Lambda Layer, EventBridge Scheduler, SES (domínio verificado, DKIM, DMARC, template).

**Outputs:** `rds_proxy_endpoint`, `rds_proxy_readonly_endpoint`, `documentdb_cluster_endpoint`, `email_notification_queue_url`, `product_stock_queue_url`, `invoice_queue_url`, `order_confirmed_topic_arn`, `order_confirmed_lambda_url`.

> Estes outputs são os placeholders `<TERRAFORM_OUTPUT:...>` que devem ser preenchidos no `config-map.yml` do repositório GitOps antes de ativar o ArgoCD.

---

## Stack 5 — site

Frontend/CDN e CI/CD keyless. Depende de outputs das Stacks 2 e 3.

```bash
cd terraform/site
terraform init
terraform apply -var-file="envs/production.tfvars"
```

**Recursos criados:** S3 site + S3 staging (buckets privados com OAC), CloudFront produção + staging, Continuous Deployment Policy (Blue/Green por header), WAF v2 (geo + managed rules + block por label), VPC Origin → ALB interno, OIDC Provider IAM + roles GitHub Actions (backend e frontend), registro A Route53 → CloudFront.

**Outputs:** `github_backend_role_arn`, `github_frontend_role_arn`, `cloudfront_distribution_id`, `site_bucket_name`.

> Os ARNs das roles IAM devem ser configurados como variáveis nos workflows do repositório `devopsproject-ecommerce` (GitHub Actions).

---

## Stack 6 — observability

Observabilidade centralizada. Depende da instance role dos nodes (Stack 3).

```bash
cd terraform/observability
terraform init
terraform apply -var-file="envs/production.tfvars"
```

**Recursos criados:** Domínio OpenSearch (`devopsproject-logs`, 1×t3.medium.search, EBS 20GB, TLS 1.2, fine-grained security), IAM policy na instance role dos nodes (`es:ESHttp*`), roles mapping (`all_access` para a role da instância e usuário `admin`).

**Outputs:** `opensearch_endpoint`.

### Instalar agentes no cluster (Ansible)

Após o Terraform criar o OpenSearch, executar as roles de observabilidade:

```bash
cd ansible/

# Fluent Bit (coleta de logs via SigV4 — usa IMDS hop limit=2 configurado na Stack 3)
ansible-playbook -i production.aws_ec2.yml site.yml --tags fluent-bit

# Metricbeat (coleta de métricas via usuário/senha)
ansible-playbook -i production.aws_ec2.yml site.yml --tags metricbeat
```

> Verificar que os logs chegam ao OpenSearch: `https://<opensearch_endpoint>/_dashboards`

---

## Convenções de código

Este repositório segue as convenções definidas em [`.claude/rules/terraform-naming-conventions.md`](../.claude/rules/terraform-naming-conventions.md):

- Identificadores com `_` (nunca `-`)
- Arquivos `.tf` com nomenclatura semântica por ponto (`vpc.tf`, `vpc.nat-gateways.tf`, etc.)
- Variáveis agrupadas por objeto — sem `default`, valores em `envs/production.tfvars`
- `count`/`for_each` primeiro no bloco; `tags` por último
- Apenas provider nativo `hashicorp/aws` — sem módulos comunitários

---

## Grafo de dependências e contratos de outputs

```
backend
  └─► networking
        ├─► server ──────────────────────────────────► observability
        │     │  (SGs)                                    (instance role)
        │     ├─► serverless
        │     │     (endpoints → GitOps config-map)
        │     ├─► site
        │     │     (ALB, ACM → CloudFront VPC Origin)
        │     └─► [Ansible] cluster K8s + controllers AWS
        └─► site
              (zone_id, subnets → Route53 + CloudFront)
```

| Output (stack origem) | Consumidor | Uso |
|---|---|---|
| `vpc_id`, `private_subnets_ids`, `route53_zone_id` (networking) | server, serverless, site | data sources de rede e DNS |
| `nlb_dns_name` (server) | Ansible | `controlPlaneEndpoint` no kubeadm |
| `acm_certificate_arn` (server) | site | certificado viewer do CloudFront |
| `control_plane_security_group_id`, `worker_security_group_id` (server) | serverless | ingress rules dos bancos |
| `ecr_repository_urls` (server) | GitHub Actions (CI/CD), GitOps | build e deploy das imagens |
| `rds_proxy_endpoint`, `documentdb_cluster_endpoint` (serverless) | GitOps | `config-map.yml` dos microsserviços |
| `opensearch_endpoint` (observability) | Ansible (fluent-bit, metricbeat) | `values.yaml` dos agentes |
| `github_backend_role_arn` (site) | GitHub Actions | `assume-role` no pipeline de backend |
