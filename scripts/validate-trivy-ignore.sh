#!/usr/bin/env bash
set -euo pipefail

POLICY_FILE="${1:-.trivyignore.yaml}"
IGNORE_FILE="${2:-.trivyignore}"

if [[ ! -f "${POLICY_FILE}" ]]; then
  echo "trivy ignore policy not found: ${POLICY_FILE}" >&2
  exit 1
fi

if [[ ! -f "${IGNORE_FILE}" ]]; then
  echo "trivy ignore list not found: ${IGNORE_FILE}" >&2
  exit 1
fi

python3 - "${POLICY_FILE}" "${IGNORE_FILE}" <<'PY'
import datetime as dt
import re
import sys
from pathlib import Path

policy_path = Path(sys.argv[1])
ignore_path = Path(sys.argv[2])
lines = policy_path.read_text(encoding="utf-8").splitlines()

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

# Ensure runtime ignore list exactly matches policy IDs.
ignore_ids = []
for raw in ignore_path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    ignore_ids.append(line)

bad_ignore_ids = [cve for cve in ignore_ids if not re.fullmatch(r"CVE-\d{4}-\d{4,}", cve)]
for bad in bad_ignore_ids:
    errors.append(f"invalid CVE id in ignore list: {bad!r}")

ignore_set = set(ignore_ids)
if ignore_set != seen:
    missing_in_ignore = sorted(seen - ignore_set)
    extra_in_ignore = sorted(ignore_set - seen)
    if missing_in_ignore:
        errors.append(f"missing from {ignore_path}: {', '.join(missing_in_ignore)}")
    if extra_in_ignore:
        errors.append(f"extra in {ignore_path}: {', '.join(extra_in_ignore)}")

if errors:
    print("trivy ignore policy validation failed:", file=sys.stderr)
    for err in errors:
        print(f" - {err}", file=sys.stderr)
    sys.exit(1)

print(f"trivy ignore policy valid ({len(entries)} entries)")
PY
