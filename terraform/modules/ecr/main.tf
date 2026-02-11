locals {
  repository_set = toset(var.repositories)
}

resource "aws_ecr_repository" "this" {
  for_each = local.repository_set

  name = format("%s/%s", var.repository_namespace, each.key)
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  image_tag_mutability = lookup(
    var.image_tag_mutability_overrides,
    each.key,
    var.default_image_tag_mutability
  )

  tags = merge(var.tags, {
    Name = format("%s_%s", var.repository_namespace, each.key)
  })
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_expiration_days
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Retain latest images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
