# ═══════════════════════════════════════════════════════════
# GOOD PATTERN: Retrieve from Secrets Manager at runtime
# ═══════════════════════════════════════════════════════════
# SECURE because:
#   1. No credentials in source code (nothing to leak in git)
#   2. No credentials in environment variables (nothing in console)
#   3. No credentials on disk (nothing to steal from server)
#   4. Every retrieval is logged in CloudTrail (full audit trail)
#   5. IAM controls who can access the secret (least privilege)
#   6. KMS controls who can decrypt (defense in depth)
#   7. Rotation happens automatically (reduced blast radius)
#   8. If compromised, you rotate once and all apps get the new cred


import boto3
import json
import os
import psycopg2


# Cache to avoid calling Secrets Manager on every request
_cached_creds = None


def get_db_credentials():
    """Retrieve database credentials from Secrets Manager."""
    global _cached_creds
    if _cached_creds:
        return _cached_creds
    
    client = boto3.client('secretsmanager')
    secret_id = os.environ['SECRET_ARN']  # Pass ARN, not the secret itself
    
    response = client.get_secret_value(SecretId=secret_id)
    _cached_creds = json.loads(response['SecretString'])
    return _cached_creds




def get_db_connection():
    """Connect to the database using credentials from Secrets Manager."""
    creds = get_db_credentials()
    return psycopg2.connect(
        host=creds['host'],
        user=creds['username'],
        password=creds['password'],
        dbname=creds['dbname'],
        port=creds['port']
    )
