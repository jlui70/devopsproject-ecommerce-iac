# ADR-0005 (origem) / ADR-0023 (movido de `site` para `cicd`).
#
# Provider OIDC do GitHub Actions — recurso global da conta, sem nenhuma
# dependencia de rede, cluster, ALB ou CloudFront. Ficava dentro da stack `site`
# por acidente historico, o que prendia toda a configuracao de CI/CD a ultima
# stack do deploy. Aqui ele e' aplicavel logo depois de `server`.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.github.oidc_thumbprint]

  tags = { Name = "devopsproject-github-oidc-provider" }
}
