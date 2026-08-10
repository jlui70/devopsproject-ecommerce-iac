# ADR-0020: expira tags transitorias sha-* (usadas so durante a validacao em
# staging) apos 30 dias. Tags release-* (historico oficial de producao) NAO tem
# regra de expiracao aqui — nenhuma regra correspondente = retencao indefinida
# (comportamento padrao do ECR lifecycle quando a imagem nao casa com nenhuma
# regra de selecao).

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expira tags sha-* (staging) apos 30 dias"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-"]
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
