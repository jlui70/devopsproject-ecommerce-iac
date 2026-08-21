# ADR-0023 — buckets de apoio que antes eram pre-requisitos manuais invisiveis.
#
# Os dois buckets abaixo nao eram criados por nenhum `.tf`: viviam como `aws s3 mb`
# soltos em docs/ansible-troubleshooting-cluster-k8s.md e em
# docs/implementation/IMPL-ADR-0002-2026-06-27.md, referenciados por
# ansible/group_vars/all.yml (ansible_aws_ssm_bucket_name) e por
# terraform/server/envs/production.tfvars (ssm_patch.bucket_name). Um deploy do zero
# feito por quem nao conhecia esses documentos falhava no primeiro `ansible all -m ping`
# sem uma mensagem que apontasse a causa. Como a stack `backend` ja e' a primeira do
# processo e nao depende de nada, e' o lugar natural para eles.

# Bucket de transporte da conexao SSM do Ansible (community.aws.aws_ssm connection
# plugin usa S3 para trafegar stdin/stdout dos comandos).
resource "aws_s3_bucket" "ansible_ssm" {
  bucket = var.support_buckets.ansible_ssm_name
}

resource "aws_s3_bucket_public_access_block" "ansible_ssm" {
  bucket = aws_s3_bucket.ansible_ssm.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ansible_ssm" {
  bucket = aws_s3_bucket.ansible_ssm.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Objetos de transporte do SSM sao efemeros — sem expiracao o bucket cresce
# indefinidamente a cada execucao do Ansible.
resource "aws_s3_bucket_lifecycle_configuration" "ansible_ssm" {
  bucket = aws_s3_bucket.ansible_ssm.id

  rule {
    id     = "expire-ssm-transport-objects"
    status = "Enabled"

    # prefixo vazio = aplica a todos os objetos do bucket
    filter {
      prefix = ""
    }

    expiration {
      days = 1
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Bucket de saida dos relatorios de patch do SSM (aws_ssm_patch_baseline /
# aws_ssm_association na stack `server`).
resource "aws_s3_bucket" "patch_logs" {
  bucket = var.support_buckets.patch_logs_name
}

resource "aws_s3_bucket_public_access_block" "patch_logs" {
  bucket = aws_s3_bucket.patch_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "patch_logs" {
  bucket = aws_s3_bucket.patch_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "patch_logs" {
  bucket = aws_s3_bucket.patch_logs.id

  rule {
    id     = "expire-patch-reports"
    status = "Enabled"

    # prefixo vazio = aplica a todos os objetos do bucket
    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }
  }
}
