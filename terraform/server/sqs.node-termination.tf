data "aws_iam_policy_document" "node_termination_sqs" {
  statement {
    sid    = "AllowASGAndEventsToSendMessages"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "autoscaling.amazonaws.com"]
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.node_termination.arn]
  }
}

resource "aws_sqs_queue" "node_termination" {
  name = "NodeTerminationQueue"

  tags = { Name = "NodeTerminationQueue" }
}

resource "aws_sqs_queue_policy" "node_termination" {
  queue_url = aws_sqs_queue.node_termination.id
  policy    = data.aws_iam_policy_document.node_termination_sqs.json
}
