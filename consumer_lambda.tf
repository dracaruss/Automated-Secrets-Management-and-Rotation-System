# ─────────────────────────────────────────────────────────────
# LAMBDA CODE: Consumer (sample app that reads the secret)
# ─────────────────────────────────────────────────────────────
data "archive_file" "consumer_lambda" {
  type        = "zip"
  output_path = "${path.module}/consumer_lambda.zip"


  source {
    content  = <<-PYTHON
import boto3
import json
import os
import logging


logger = logging.getLogger()
logger.setLevel(logging.INFO)


# Cache the secret to avoid calling Secrets Manager on every invocation.
# Lambda containers are reused, so this persists across warm invocations.
# The secret is refreshed when the container is recycled (cold start).
_cached_secret = None


def get_db_credentials():
    """
    Retrieve database credentials from Secrets Manager.
    Uses caching to minimize API calls and reduce latency.
    
    Returns:
        dict with keys: username, password, host, port, dbname, engine
    """
    global _cached_secret
    
    if _cached_secret is not None:
        logger.info('Using cached credentials')
        return _cached_secret
    
    secret_id = os.environ['SECRET_ARN']
    client = boto3.client('secretsmanager')
    
    response = client.get_secret_value(SecretId=secret_id)
    _cached_secret = json.loads(response['SecretString'])
    
    logger.info(f'Retrieved fresh credentials for user: {_cached_secret["username"]}')
    # NEVER log the actual password
    
    return _cached_secret




def lambda_handler(event, context):
    """
    Sample application handler that uses database credentials.
    In a real app, this would connect to the database.
    """
    creds = get_db_credentials()
    
    # Demonstrate we have the credentials (without exposing the password)
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Successfully retrieved database credentials',
            'username': creds['username'],
            'host': creds['host'],
            'port': creds['port'],
            'dbname': creds['dbname'],
            'password_length': len(creds['password']),
            'password_retrieved': True
            # NEVER include the actual password in a response
        })
    }
PYTHON
    filename = "consumer_app.py"
  }
}


# ── IAM Role for Consumer Lambda ──────────────────────────
resource "aws_iam_role" "consumer_lambda" {
  name = "secrets-consumer-lambda-role"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}


# Attach the read-only secret policy we created in secret.tf
resource "aws_iam_role_policy_attachment" "consumer_read_secret" {
  role       = aws_iam_role.consumer_lambda.name
  policy_arn = aws_iam_policy.read_db_secret.arn
}


resource "aws_iam_role_policy" "consumer_logs" {
  name = "consumer-cloudwatch-logs"
  role = aws_iam_role.consumer_lambda.id


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}


# ── The Consumer Lambda Function ──────────────────────────
resource "aws_lambda_function" "consumer" {
  function_name    = "secrets-consumer-app"
  filename         = data.archive_file.consumer_lambda.output_path
  source_code_hash = data.archive_file.consumer_lambda.output_base64sha256
  handler          = "consumer_app.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
  role             = aws_iam_role.consumer_lambda.arn


  environment {
    variables = {
      # Pass the secret ARN, NOT the secret value.
      # The Lambda retrieves the value at runtime.
      SECRET_ARN = aws_secretsmanager_secret.db_creds.arn
    }
  }


  tags = {
    Name    = "secrets-consumer-app"
    Purpose = "demo-secret-retrieval"
  }
}


resource "aws_cloudwatch_log_group" "consumer_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.consumer.function_name}"
  retention_in_days = 7
  tags              = { Name = "consumer-lambda-logs" }
}
