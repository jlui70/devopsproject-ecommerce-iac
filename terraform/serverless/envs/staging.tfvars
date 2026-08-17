# ADR-0012 — camada de dados/mensageria isolada do ambiente staging.
#
# Escopo deste arquivo: `production_enabled = false` + a variavel `staging`
# (var.staging em variables.tf), que juntas controlam os recursos aditivos
# (count) nos mesmos .tf da stack `serverless` — Aurora, DocumentDB, SQS e
# segredos correspondentes. Ele NAO duplica os blocos region/assume_role/
# aurora/docdb/sqs/sns/lambda/ses/app/aurora_master_password de
# envs/production.tfvars: esses recursos permanecem exclusivos de producao e
# nao sao recriados para staging (SES e explicitamente reaproveitado —
# Decisao 4 do ADR-0012; SNS/Lambda/S3/RDS Proxy nao fazem parte do escopo de
# isolamento deste ADR).
#
# RESOLVIDO em 2026-08-10: state key separada por ambiente, implementada via
# `production_enabled` (variables.tf) + cross-state remote state para os
# poucos recursos genuinamente compartilhados (SGs de postgresql/documentdb,
# subnet groups do Aurora/DocumentDB, e o cluster parameter group do
# DocumentDB — este ultimo identificado durante a implementacao, nao listado
# no ADR-0012 original, mas tratado com o mesmo padrao por ser tambem
# referenciado diretamente pelo cluster DocumentDB staging).
#
# Como aplicar cada ambiente isoladamente, cada um contra sua propria state key:
#
#   # Producao — key default (serverless/terraform.tfstate):
#   terraform init
#   terraform apply -var-file="envs/production.tfvars"
#
#   # Staging — key separada (serverless/staging/terraform.tfstate), reconfigura
#   # o backend do MESMO diretorio .tf para apontar para outro state:
#   terraform init -reconfigure -backend-config="key=serverless/staging/terraform.tfstate"
#   terraform apply -var-file="envs/production.tfvars" -var-file="envs/staging.tfvars"
#
# Todos os recursos de producao (Aurora, DocumentDB, SQS, SNS, Lambda, SES, S3,
# RDS Proxy, SGs, subnet groups) agora sao gateados por
# `count = var.production_enabled ? 1 : 0` — aplicar contra a state key de
# staging NAO tenta mais recria-los (o state e' separado). Os poucos recursos
# compartilhados entre os dois states (SGs de postgresql/documentdb, subnet
# groups, parameter group do DocumentDB) sao lidos do state de producao via
# `data.terraform_remote_state.serverless_production` quando
# production_enabled=false — ver data.serverless-production.tf e os outputs
# correspondentes em outputs.tf.
#
# CORRIGIDO em 2026-08-10 (achado ao vivo no primeiro deploy real): ainda e'
# preciso passar os DOIS var-files juntos, nesta ordem, mesmo aplicando contra
# a state key de staging. O motivo NAO e' colisao de recursos (isso ja esta
# resolvido pelo count acima) — e' que `aurora`, `docdb`, `sqs`, `sns`,
# `lambda`, `ses`, `app` e `aurora_master_password` continuam `nullable = false`
# sem default em variables.tf, e o Terraform exige valor pra toda variavel
# declarada ANTES de avaliar o `count` dos recursos que a usam. Este arquivo
# nao redeclara essas variaveis de proposito (ficariam duplicadas com
# production.tfvars) — passar production.tfvars primeiro so "empresta" esses
# valores (nunca chegam a ser usados, ja que os recursos que os consomem tem
# count=0 quando production_enabled=false); staging.tfvars, passado depois,
# sobrescreve production_enabled para false e preenche o bloco staging.
# Aplicar so com um dos dois falha pedindo os valores interativamente
# ("Enter a value:").

production_enabled = false

staging = {
  enabled = true

  aurora = {
    cluster_identifier           = "devopsproject-stg-aurora"
    database_name                = "devopsprojectEcommerce"
    master_username              = "devopsprojectAdmin"
    min_capacity                 = 0
    max_capacity                 = 2
    seconds_until_auto_pause     = 900
    backup_retention_period      = 1
    preferred_backup_window      = "01:00-02:00"
    preferred_maintenance_window = "sun:05:00-sun:06:00"
  }

  docdb = {
    cluster_identifier           = "devopsproject-stg-docdb"
    engine_version               = "5.0"
    instance_class               = "db.t3.medium"
    backup_retention_period      = 1
    preferred_backup_window      = "01:00-02:00"
    preferred_maintenance_window = "sun:03:00-sun:04:00"
  }

  sqs = {
    email_notification_queue_name = "EmailNotificationQueue-stg"
    email_notification_dlq_name   = "EmailNotificationQueueDlq-stg"
    product_stock_queue_name      = "ProductStockQueue-stg"
    product_stock_dlq_name        = "ProductStockQueueDlq-stg"
    invoice_queue_name            = "InvoiceQueue-stg"
    invoice_dlq_name              = "InvoiceQueueDlq-stg"
  }

}

# Senha do usuario admin da aplicacao (identity-server) em staging — isolada da
# senha de producao, coerente com o principio de credenciais isoladas por
# ambiente do ADR-0011/0012. NAO incluir aqui — injetar via:
# export TF_VAR_staging_app_identity_admin_password="<senha forte, nunca a de producao>"
