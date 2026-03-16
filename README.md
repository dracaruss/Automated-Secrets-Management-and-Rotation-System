Cloud Security Portfolio: Automated Secrets Management
Project Overview
Leaked credentials are a leading cause of cloud breaches. This project demonstrates a production-grade Secrets Management architecture on AWS using Terraform. It moves beyond simple storage by implementing automated rotation, least-privilege IAM access, and customer-managed encryption.

The goal is to eliminate "secret sprawl" where passwords live in source code, environment variables, or plaintext configuration files.

🏗 Key Architectural Decisions
1. Customer-Managed Encryption (KMS)
Instead of using the default AWS-managed key, I deployed a Customer-Managed KMS Key.

Context-Aware Security: The key policy uses kms:ViaService to ensure the key only decrypts data when the request originates from Secrets Manager.

Full Auditability: Every decryption event is logged in CloudTrail with a unique fingerprint.

Emergency Revocation: As the owner, I can disable the key to instantly "freeze" all access to the credentials.

2. Atomic 4-Step Rotation (Lambda)
I implemented a Lambda function to handle the AWS Secrets Manager rotation lifecycle. This ensures a "zero-downtime" transition:

createSecret: Generates a new cryptographically strong 32-character password (AWSPENDING).

setSecret: Updates the target database (stubbed in this lab).

testSecret: Verifies the new credential works before committing.

finishSecret: Swaps the AWSCURRENT label to the new version.

3. Runtime Retrieval Pattern
The sample application (Consumer Lambda) never "sees" the password until it is needed in memory.

Environment Variables: Only the Secret ARN is passed as an env var, not the secret itself.

Memory-Only Access: Credentials are fetched at runtime and stored in memory, never written to disk or logged.

📂 Project Structure
Plaintext
07-secrets-management/
├── providers.tf         # AWS, Random, and Archive providers
├── kms.tf               # Customer-managed KMS key and policy
├── secret.tf            # Secrets Manager resource and rotation schedule
├── rotation_lambda.tf   # Python logic for the 4-step rotation
├── consumer_lambda.tf   # Sample app demonstrating secure retrieval
└── examples/            # Documentation of Bad vs. Good patterns
🚀 Deployment & Validation
Step 1: Deploy Infrastructure
Bash
terraform init
terraform apply -auto-approve
Step 2: Test Automated Rotation
Trigger a manual rotation to prove the Lambda works and the password changes:

Bash
# Force a rotation
aws secretsmanager rotate-secret --secret-id prod/database/credentials

# Verify the password changed (Compare 'Before' and 'After' hashes)
aws secretsmanager get-secret-value --secret-id prod/database/credentials --query SecretString
Step 3: Test Application Retrieval
Invoke the consumer Lambda to confirm it can successfully decrypt and use the new credential:

Bash
aws lambda invoke --function-name secrets-consumer-app response.json
cat response.json
🛡️ Security Best Practices Demonstrated
Least Privilege: The Consumer Lambda's IAM role is restricted to a single Secret ARN and a single KMS Key ARN.

No Hardcoded Secrets: Used Terraform's random_password for the initial bootstrap.

Lifecycle Management: Used ignore_changes in Terraform to allow the Rotation Lambda to take ownership of the credential after deployment.

Log Retention: Configured CloudWatch Log Groups with 30-day expiration to manage costs and data privacy.
