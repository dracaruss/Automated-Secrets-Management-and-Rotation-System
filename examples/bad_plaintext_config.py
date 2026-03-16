BAD PATTERN: Secrets in a config file that gets deployed with the code.
# ═══════════════════════════════════════════════════════════
# BAD PATTERN: Secrets in a config file
# ═══════════════════════════════════════════════════════════
# RISKY because:
#   1. Config files get committed to git
#   2. Config files are often readable by anyone on the server
#   3. If the server is compromised, attacker reads the file
#   4. Backups of the server contain the plaintext password


import json


# config.json (deployed alongside the code):
# {
#   "database": {
#     "host": "database.internal.example.com",
#     "user": "app_user",
#     "password": "SuperSecret123!",  <-- This is the problem
#     "dbname": "appdb"
#   }
# }


with open('config.json') as f:
    config = json.load(f)


password = config['database']['password']  # plaintext on disk
