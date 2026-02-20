#!/usr/bin/env bash
set -euo pipefail

FILE="${1:-.trivyignore.yaml}"

if [[ ! -f "${FILE}" ]]; then
  echo "trivy ignore policy not found: ${FILE}" >&2
  exit 1
fi

python3 - "${FILE}" <<'PY'
import datetime as dt
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()

entries = []
current = None

for raw in lines:
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    if line.startswith("- id:"):
        if current is not None:
            entries.append(current)
        current = {"id": line.split(":", 1)[1].strip()}
        continue
    if current is None:
        continue
    if line.startswith("statement:"):
        current["statement"] = line.split(":", 1)[1].strip()
    elif line.startswith("expired_at:"):
        current["expired_at"] = line.split(":", 1)[1].strip()

if current is not None:
    entries.append(current)

if not entries:
    print("no vulnerability entries found in trivy ignore policy", file=sys.stderr)
    sys.exit(1)

today = dt.date.today()
seen = set()
errors = []

for entry in entries:
    cve = entry.get("id", "")
    if not re.fullmatch(r"CVE-\d{4}-\d{4,}", cve):
        errors.append(f"invalid CVE id: {cve!r}")
    if cve in seen:
        errors.append(f"duplicate CVE id: {cve}")
    seen.add(cve)

    statement = entry.get("statement", "").strip()
    if len(statement) < 20:
        errors.append(f"{cve}: missing/short statement")

    expires = entry.get("expired_at", "").strip()
    try:
        exp_date = dt.date.fromisoformat(expires)
    except ValueError:
        errors.append(f"{cve}: invalid expired_at date: {expires!r}")
        continue
    if exp_date < today:
        errors.append(f"{cve}: expired on {exp_date.isoformat()}")

if errors:
    print("trivy ignore policy validation failed:", file=sys.stderr)
    for err in errors:
        print(f" - {err}", file=sys.stderr)
    sys.exit(1)

print(f"trivy ignore policy valid ({len(entries)} entries)")
PY
