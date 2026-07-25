resource "terraform_data" "attach_continuous_deployment_policy" {
  triggers_replace = [
    aws_cloudfront_distribution.production.id,
    aws_cloudfront_continuous_deployment_policy.this.id,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      DIST_ID="${aws_cloudfront_distribution.production.id}"
      POLICY_ID="${aws_cloudfront_continuous_deployment_policy.this.id}"
      TMP_FILE="/tmp/dist-config-$DIST_ID.json"

      ETAG=$(aws cloudfront get-distribution-config \
        --id "$DIST_ID" \
        --query 'ETag' --output text)

      aws cloudfront get-distribution-config \
        --id "$DIST_ID" \
        --query 'DistributionConfig' \
        --output json > "$TMP_FILE"

      python3 -c "
import json
with open('$TMP_FILE') as f:
    config = json.load(f)
config['ContinuousDeploymentPolicyId'] = '$POLICY_ID'
config['WebACLId'] = ''
with open('$TMP_FILE', 'w') as f:
    json.dump(config, f)
"

      aws cloudfront update-distribution \
        --id "$DIST_ID" \
        --distribution-config "file://$TMP_FILE" \
        --if-match "$ETAG"

      rm -f "$TMP_FILE"
    EOT
  }
}
