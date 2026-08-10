# ADR-0012 (state key separada por ambiente): Security Groups, Subnet Groups e o
# Cluster Parameter Group do DocumentDB sao recursos compartilhados entre
# producao e staging na camada de rede/parametrizacao, mas so existem no state
# de PRODUCAO (aws_security_group.postgresql, aws_security_group.documentdb,
# aws_db_subnet_group.this, aws_docdb_subnet_group.this e
# aws_docdb_cluster_parameter_group.this — todos gateados por
# var.production_enabled). Quando esta mesma stack e aplicada isoladamente
# contra a state key de staging (production_enabled=false), esses recursos nao
# existem localmente: este data source busca seus IDs/nomes no state de
# producao via remote state cross-reference, permitindo que os recursos
# aws_rds_cluster.staging, aws_rds_cluster_instance.staging e
# aws_docdb_cluster.staging continuem referenciando os mesmos objetos AWS
# fisicos sem tentar recria-los em um state proprio.
#
# aws_docdb_cluster_parameter_group.this nao estava listado como recurso
# compartilhado no ADR-0012 original — foi identificado durante a
# implementacao (o cluster DocumentDB staging tambem referencia
# db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.this.name)
# e recebeu o mesmo tratamento por necessidade de correcao.
data "terraform_remote_state" "serverless_production" {
  count = var.production_enabled ? 0 : 1

  backend = "s3"

  config = {
    bucket = "devopsproject-terraform-state-692430448478"
    key    = "serverless/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  postgresql_security_group_id            = var.production_enabled ? aws_security_group.postgresql[0].id : data.terraform_remote_state.serverless_production[0].outputs.postgresql_security_group_id
  documentdb_security_group_id            = var.production_enabled ? aws_security_group.documentdb[0].id : data.terraform_remote_state.serverless_production[0].outputs.documentdb_security_group_id
  aurora_db_subnet_group_name             = var.production_enabled ? aws_db_subnet_group.this[0].name : data.terraform_remote_state.serverless_production[0].outputs.aurora_db_subnet_group_name
  documentdb_subnet_group_name            = var.production_enabled ? aws_docdb_subnet_group.this[0].name : data.terraform_remote_state.serverless_production[0].outputs.documentdb_subnet_group_name
  documentdb_cluster_parameter_group_name = var.production_enabled ? aws_docdb_cluster_parameter_group.this[0].name : data.terraform_remote_state.serverless_production[0].outputs.documentdb_cluster_parameter_group_name
}
