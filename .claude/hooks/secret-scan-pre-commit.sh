#!/usr/bin/env bash
# Hook: secret-scan-pre-commit
# Scans staged files for secrets before a commit is allowed.
# Uses gitleaks if available; falls back to a grep-based pattern scan.
set -euo pipefail

STAGED_FILES="$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)"

if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

FOUND=0

# --- Primary: gitleaks ---
if command -v gitleaks &>/dev/null; then
  if ! gitleaks protect --staged --no-banner -q 2>/dev/null; then
    cat >&2 <<'EOF'
ERROR: gitleaks detected potential secrets in staged files.
Run `gitleaks protect --staged` for details.
Remove or rotate the secret before committing.
If this is a false positive, add an inline `# gitleaks:allow` comment and document why.
EOF
    exit 2
  fi
  exit 0
fi

# --- Fallback: grep patterns ---
echo "gitleaks not found — falling back to pattern scan." >&2

SECRET_PATTERNS=(
  'AKIA[0-9A-Z]{16}'                          # AWS Access Key ID
  'aws_secret_access_key\s*=\s*["\x27][^"]+["\x27]'  # AWS Secret Key in config
  'password\s*=\s*["\x27][^"]{8,}["\x27]'    # Generic password assignment
  'secret\s*=\s*["\x27][^"]{8,}["\x27]'      # Generic secret assignment
  'token\s*=\s*["\x27][^"]{16,}["\x27]'      # Generic token assignment
  'BEGIN (RSA|EC|OPENSSH|PGP) PRIVATE KEY'    # Private keys
  'ghp_[0-9a-zA-Z]{36}'                       # GitHub personal access token
  'xox[baprs]-[0-9a-zA-Z\-]+'                # Slack tokens
  'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.' # JWT
  'AIza[0-9A-Za-z\-_]{35}'                    # Google API key
)

while IFS= read -r file; do
  [ -f "$file" ] || continue
  # Skip non-text files using MIME type — more reliable than matching the word 'binary'
  if ! file --mime-type "$file" | grep -q 'text/'; then
    continue
  fi
  for pattern in "${SECRET_PATTERNS[@]}"; do
    if git show ":$file" 2>/dev/null | grep -qP "$pattern" 2>/dev/null; then
      echo "ERROR: Possible secret matched pattern '$pattern' in $file" >&2
      FOUND=1
    fi
  done
done <<< "$STAGED_FILES"

if [ "$FOUND" -eq 1 ]; then
  cat >&2 <<'EOF'

Commit blocked. Remove or rotate any exposed secrets.
If this is a false positive, install gitleaks and use `# gitleaks:allow` inline.
EOF
  exit 2
fi

exit 0
