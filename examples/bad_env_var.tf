# ═══════════════════════════════════════════════════════════
# BAD PATTERN: Secret in environment variable
# ═══════════════════════════════════════════════════════════
# RISKY because:
#   1. Visible in plaintext in the Lambda console
#   2. Stored in plaintext in CloudFormation/Terraform state
#   3. If someone runs 'printenv' or logs all env vars, it's exposed
#   4. Anyone with lambda:GetFunctionConfiguration can see it


resource "aws_lambda_function" "bad_example" {
  function_name = "bad-secret-example"
  handler       = "app.handler"
  runtime       = "python3.12"
  role          = "arn:aws:iam::123456789012:role/some-role"
  filename      = "app.zip"


  environment {
    variables = {
      DB_HOST     = "database.internal.example.com"
      DB_USER     = "app_user"
      DB_PASSWORD = "SuperSecret123!"  # <-- This is the problem
      DB_NAME     = "appdb"
    }
  }
}
