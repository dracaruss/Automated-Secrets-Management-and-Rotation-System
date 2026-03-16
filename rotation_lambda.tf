# ─────────────────────────────────────────────────────────────
# LAMBDA CODE: Secret Rotation
# ─────────────────────────────────────────────────────────────
data "archive_file" "rotation_lambda" {
  type        = "zip"
  output_path = "${path.module}/rotation_lambda.zip"


  source {
    content  = <<-PYTHON
import boto3
import json
import string
import random
import logging


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """
    Secrets Manager rotation handler.
    
    Secrets Manager calls this Lambda with four different 'steps':
      1. createSecret  — Generate a new password and store as AWSPENDING
      2. setSecret     — Update the actual database with the new password
      3. testSecret    — Verify the new password works against the database
      4. finishSecret  — Promote AWSPENDING to AWSCURRENT
    
    In this lab, steps 2 and 3 are stubbed because we don't have a real
    database. In production, these would execute actual SQL commands.
    """
    secret_id = event['SecretId']
    step = event['Step']
    token = event['ClientRequestToken']
    
    client = boto3.client('secretsmanager')
    
    logger.info(f'Rotation step: {step} for secret: {secret_id}')
    
    if step == 'createSecret':
        _create_secret(client, secret_id, token)
    elif step == 'setSecret':
        _set_secret(client, secret_id, token)
    elif step == 'testSecret':
        _test_secret(client, secret_id, token)
    elif step == 'finishSecret':
        _finish_secret(client, secret_id, token)
    else:
        raise ValueError(f'Unknown step: {step}')




def _create_secret(client, secret_id, token):
    """Generate a new password and store it as AWSPENDING."""
    
    # Get the current secret
    current = json.loads(
        client.get_secret_value(
            SecretId=secret_id,
            VersionStage='AWSCURRENT'
        )['SecretString']
    )
    
    # Generate a new password
    chars = string.ascii_letters + string.digits + '!@#$%^&*()'
    new_password = ''.join(random.SystemRandom().choice(chars) for _ in range(32))
    current['password'] = new_password
    
    # Store the new version as AWSPENDING
    client.put_secret_value(
        SecretId=secret_id,
        ClientRequestToken=token,
        SecretString=json.dumps(current),
        VersionStages=['AWSPENDING']
    )
    
    logger.info(f'createSecret: New password generated and stored as AWSPENDING')




def _set_secret(client, secret_id, token):
    """
    Update the actual database with the new password.
    
    In production, this would:
      1. Retrieve the AWSPENDING secret
      2. Connect to the database using the CURRENT master credentials
      3. Execute ALTER USER app_user PASSWORD 'new_password'
    
    STUBBED for this lab — no real database exists.
    """
    logger.info(f'setSecret: STUBBED — would update database password here')




def _test_secret(client, secret_id, token):
    """
    Verify the new password works by connecting to the database.
    
    In production, this would:
      1. Retrieve the AWSPENDING secret
      2. Attempt to connect to the database with the new password
      3. Run a simple query (SELECT 1) to verify
      4. Raise an exception if connection fails (triggers rollback)
    
    STUBBED for this lab — no real database exists.
    """
    logger.info(f'testSecret: STUBBED — would test database connection here')




def _finish_secret(client, secret_id, token):
    """Promote AWSPENDING to AWSCURRENT."""
    
    # Get all versions of the secret
    metadata = client.describe_secret(SecretId=secret_id)
    
    # Find the current version and demote it
    for version_id, stages in metadata['VersionIdsToStages'].items():
        if 'AWSCURRENT' in stages and version_id != token:
            # Promote the pending version to current
            client.update_secret_version_stage(
                SecretId=secret_id,
                VersionStage='AWSCURRENT',
                MoveToVersionId=token,
                RemoveFromVersionId=version_id
            )
            logger.info(f'finishSecret: Promoted {token} to AWSCURRENT, demoted {version_id}')
            break
PYTHON
    filename = "rotate_secret.py"
  }
}


# ─────────────────────────────────────────────────────────────
# IAM ROLE: Rotation Lambda
# ─────────────────────────────────────────────────────────────
resource "aws_iam_role" "rotation_lambda" {
  name = "secrets-rotation-lambda-role"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_role_policy" "rotation_lambda" {
  name = "secrets-rotation-policy"
  role = aws_iam_role.rotation_lambda.id


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:UpdateSecretVersionStage",
          "secretsmanager:GetRandomPassword"
        ]
        Resource = aws_secretsmanager_secret.db_creds.arn
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.secrets.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}


# ─────────────────────────────────────────────────────────────
# LAMBDA FUNCTION: Rotation
# ─────────────────────────────────────────────────────────────
resource "aws_lambda_function" "rotate_secret" {
  function_name    = "secrets-rotation-function"
  filename         = data.archive_file.rotation_lambda.output_path
  source_code_hash = data.archive_file.rotation_lambda.output_base64sha256
  handler          = "rotate_secret.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60
  role             = aws_iam_role.rotation_lambda.arn


  tags = {
    Name    = "secrets-rotation-function"
    Purpose = "credential-rotation"
  }
}


# ─────────────────────────────────────────────────────────────
# PERMISSION: Allow Secrets Manager to invoke the Lambda
# ─────────────────────────────────────────────────────────────
resource "aws_lambda_permission" "secrets_manager" {
  statement_id  = "AllowSecretsManagerInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotate_secret.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.db_creds.arn
}


# ── CloudWatch Log Group with retention ───────────────────
resource "aws_cloudwatch_log_group" "rotation_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.rotate_secret.function_name}"
  retention_in_days = 30
  tags              = { Name = "secrets-rotation-logs" }
}
