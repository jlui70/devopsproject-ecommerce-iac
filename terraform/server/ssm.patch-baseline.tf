resource "aws_ssm_patch_baseline" "this" {
  name             = "DebianProductionPatchBaseline"
  operating_system = "DEBIAN"

  approval_rule {
    approve_after_days = 0
    patch_filter {
      key    = "PRODUCT"
      values = ["Debian12"]
    }
    patch_filter {
      key    = "PRIORITY"
      values = ["Required", "Important"]
    }
  }

  tags = { Name = "DebianProductionPatchBaseline" }
}
