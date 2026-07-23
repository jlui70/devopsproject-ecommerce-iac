resource "aws_launch_template" "this" {
  name_prefix   = "${var.config.name}-"
  image_id      = var.config.ami_id
  instance_type = var.config.instance_type
  key_name      = var.config.key_name

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Install AWS SSM Agent — required for Ansible via SSM (Debian 12 does not ship with it)
    mkdir -p /tmp/ssm
    curl -sL https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb \
      -o /tmp/ssm/amazon-ssm-agent.deb
    dpkg -i /tmp/ssm/amazon-ssm-agent.deb
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOF
  )

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.config.ebs_size_gb
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  iam_instance_profile {
    name = var.config.instance_profile_name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = var.config.http_put_response_hop_limit
  }

  disable_api_stop        = true
  disable_api_termination = true

  vpc_security_group_ids = var.config.security_group_ids

  lifecycle {
    ignore_changes = [image_id]
  }
}
