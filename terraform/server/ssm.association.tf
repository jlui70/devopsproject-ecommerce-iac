resource "aws_ssm_association" "patch" {
  name = "AWS-RunPatchBaseline"

  schedule_expression = var.ssm_patch.schedule

  parameters = {
    Operation    = "Install"
    RebootOption = "RebootIfNeeded"
  }

  targets {
    key    = "tag:PatchGroup"
    values = ["Production"]
  }

  max_concurrency = "1"
  max_errors      = "0"
}
