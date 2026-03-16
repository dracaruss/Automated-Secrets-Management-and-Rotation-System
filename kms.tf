# ─────────────────────────────────────────────────────────────
# DATA SOURCES
# ─────────────────────────────────────────────────────────────
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


# ─────────────────────────────────────────────────────────────
# KMS KEY: Encrypt secrets at rest
#
# Why a customer-managed key instead of the default aws/secretsmanager key?
#   1. We control the key policy (who can decrypt)
#   2. Every encrypt/decrypt is logged in CloudTrail
#   3. We can grant cross-account access if needed later
#   4. We can disable the key to instantly revoke all access
# ─────────────────────────────────────────────────────────────
resource "aws_kms_key" "secrets" {
  description             = "Encrypt Secrets Manager secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccountAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManagerService"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
            "kms:ViaService"    = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
}


resource "aws_kms_alias" "secrets" {
  name          = "alias/secrets-manager-key"
  target_key_id = aws_kms_key.secrets.key_id
}
