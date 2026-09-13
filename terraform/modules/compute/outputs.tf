output "eks_node_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "ecr_serving_url" {
  value       = var.include_pro_only_services ? aws_ecr_repository.serving[0].repository_url : null
  description = "null tant que include_pro_only_services=false (cf. main.tf)."
}
