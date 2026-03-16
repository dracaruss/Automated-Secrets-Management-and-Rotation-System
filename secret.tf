# ─────────────────────────────────────────────────────────────
# RANDOM PASSWORD: Initial database password
# Terraform generates this. After the first rotation,
# Secrets Manager owns the password and Terraform no longer
# knows the current value (which is correct behavior).
# ─────────────────────────────────────────────────────────────
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!@#$%^&*()"
  # Avoid characters that cause issues in connection strings:
  # no slashes, quotes, backslashes, or spaces
}


# ─────────────────────────────────────────────────────────────
# SECRET: Database Credentials
# Stored as a JSON object with all connection parameters.
# Applications retrieve the whole object and parse out what
# they need.
# ─────────────────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "db_creds" {
  name                    = "prod/database/credentials"
  description             = "Production database credentials — auto-rotated every ${var.rotation_days} days"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.secrets.arn


  tags = {
    Name        = "prod-database-credentials"
    Environment = "production"
    Rotation    = "enabled"
    Owner       = "platform-team"
  }
}


# ─────────────────────────────────────────────────────────────
# SECRET VERSION: The actual credential values
# ─────────────────────────────────────────────────────────────
resource "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = aws_secretsmanager_secret.db_creds.id


  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = "database.internal.example.com"
    port     = 5432
    dbname   = "appdb"
    engine   = "postgres"
  })


  # After rotation, Secrets Manager manages the value.
  # Tell Terraform to ignore changes so it doesn't try to
  # revert the rotated password back to the original.
  lifecycle {
    ignore_changes = [secret_string]
  }
}


# ─────────────────────────────────────────────────────────────
# ROTATION SCHEDULE: Auto-rotate every N days
# This connects the secret to the rotation Lambda.
# After this is enabled, Secrets Manager will invoke the
# Lambda on schedule to generate a new password.
# ─────────────────────────────────────────────────────────────
resource "aws_secretsmanager_secret_rotation" "db_creds" {
  secret_id           = aws_secretsmanager_secret.db_creds.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn


  rotation_rules {
    automatically_after_days = var.rotation_days
  }


  depends_on = [aws_lambda_permission.secrets_manager]
}


# ─────────────────────────────────────────────────────────────
# IAM POLICY: Read-only access to this specific secret
# Attach this policy to any application role that needs
# to retrieve database credentials.
#
# Note: This grants access to the SECRET only.
# The KMS key policy separately controls decrypt access.
# Both must allow the principal for retrieval to work.
# ─────────────────────────────────────────────────────────────
resource "aws_iam_policy" "read_db_secret" {
  name        = "ReadDatabaseSecret"
  description = "Allows reading the production database credentials from Secrets Manager"


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetSecretValue"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_creds.arn
      },
      {
        Sid    = "DecryptWithKMS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.secrets.arn
      }
    ]
  })
}
