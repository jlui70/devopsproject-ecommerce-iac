variable "config" {
  description = "Configuração do Launch Template e ASG"
  type = object({
    name                        = string
    ami_id                      = string
    instance_type               = string
    ebs_size_gb                 = number
    instance_profile_name       = string
    security_group_ids          = list(string)
    subnet_ids                  = list(string)
    key_name                    = string
    http_put_response_hop_limit = number
    asg = object({
      min     = number
      desired = number
      max     = number
    })
    target_group_arns   = list(string)
    suspended_processes = list(string)
    maintenance_policy = object({
      min_healthy_percentage = number
      max_healthy_percentage = number
    })
    extra_tags = map(string)
  })
  nullable = false
}
