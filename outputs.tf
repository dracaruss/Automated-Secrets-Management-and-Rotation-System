output "secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db_creds.arn
}


output "secret_name" {
  description = "Name of the database credentials secret"
  value       = aws_secretsmanager_secret.db_creds.name
}


output "kms_key_arn" {
  description = "ARN of the KMS key encrypting secrets"
  value       = aws_kms_key.secrets.arn
}


output "rotation_lambda_arn" {
  description = "ARN of the rotation Lambda function"
  value       = aws_lambda_function.rotate_secret.arn
}


output "consumer_lambda_name" {
  description = "Name of the consumer Lambda (invoke to test)"
  value       = aws_lambda_function.consumer.function_name
}


output "read_secret_policy_arn" {
  description = "ARN of the IAM policy for reading the secret. Attach to any app role."
  value       = aws_iam_policy.read_db_secret.arn
}
