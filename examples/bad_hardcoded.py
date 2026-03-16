# ═══════════════════════════════════════════════════════════
# BAD PATTERN: Hardcoded credentials
# ═══════════════════════════════════════════════════════════
# NEVER DO THIS. If this file is committed to git, the
# credentials are exposed forever (git history is permanent).
# Tools like TruffleHog and git-secrets will catch this.


import psycopg2


# THE PROBLEM: credentials are in the source code
DB_HOST = "database.internal.example.com"
DB_USER = "app_user"
DB_PASS = "SuperSecret123!"  # <-- This is the problem
DB_NAME = "appdb"


conn = psycopg2.connect(
    host=DB_HOST,
    user=DB_USER,
    password=DB_PASS,  # <-- hardcoded password
    dbname=DB_NAME
)
