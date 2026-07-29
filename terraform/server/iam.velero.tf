data "aws_iam_policy_document" "velero" {
  statement {
    sid    = "VeleroS3Backup"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      aws_s3_bucket.velero.arn,
      "${aws_s3_bucket.velero.arn}/*",
    ]
  }

  statement {
    sid    = "VeleroEC2Snapshots"
    effect = "Allow"
    actions = [
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
      "ec2:CreateSnapshot",
      "ec2:DeleteSnapshot",
      "ec2:DescribeTags",
      "ec2:CreateTags",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "velero" {
  name   = "${var.cluster.name}-velero"
  role   = aws_iam_role.worker.id
  policy = data.aws_iam_policy_document.velero.json
}
