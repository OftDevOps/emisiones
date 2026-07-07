#!/usr/bin/env bash
set -u

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR" || {
  echo "FAIL: project directory not found: $PROJECT_DIR"
  exit 1
}

failures=0
warnings=0

section() {
  printf '\n== %s ==\n' "$1"
}

warn() {
  echo "WARN: $1"
  warnings=$((warnings + 1))
}

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

ok() {
  echo "OK: $1"
}

section "136 - Inspect pilot env and exposed ports"
echo "Project: $PROJECT_DIR"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S %z')"

section "Git baseline"
git status --short
git branch --show-current
git log --oneline --max-count=5 --decorate

section "Tracked env-like files"
tracked_env_files="$(git ls-files | grep -E '(^|/)\.env($|\.)|\.env\..*|env\.py$|settings/.+\.env$' || true)"
if [ -z "$tracked_env_files" ]; then
  ok "no tracked env-like files"
else
  echo "$tracked_env_files"
  if echo "$tracked_env_files" | grep -Eq '(^|/)\.env$'; then
    fail "real .env is tracked"
  fi
  if echo "$tracked_env_files" | grep -Eq '(^|/)\.env\.example$'; then
    warn ".env.example is tracked; acceptable only if it contains placeholders and no secrets"
  fi
fi

section ".env.example sanitation check"
if [ -f ".env.example" ]; then
  echo "FOUND: .env.example"
  suspicious_lines="$(grep -nEi 'SECRET_KEY|PASSWORD|PASS|TOKEN|API_KEY|PRIVATE|ACCESS_KEY|DATABASE_URL|EMAIL_HOST_PASSWORD' .env.example || true)"
  if [ -n "$suspicious_lines" ]; then
    echo "$suspicious_lines" | sed -E 's/(=).*/=***REDACTED***/'
    if grep -Ei 'change-me|example|placeholder|dummy|your-|replace|dev-only|localhost' .env.example >/dev/null 2>&1; then
      warn ".env.example contains sensitive key names; values appear placeholder-like, review manually"
    else
      fail ".env.example contains sensitive key names without obvious placeholder markers"
    fi
  else
    ok ".env.example has no obvious sensitive keys"
  fi
else
  warn ".env.example not found"
fi

section "Local .env presence and git guard"
if [ -f ".env" ]; then
  ok ".env exists locally"
  if git ls-files --error-unmatch .env >/dev/null 2>&1; then
    fail ".env is tracked by Git"
  else
    ok ".env is not tracked by Git"
  fi
  echo "Configured key names in .env, values redacted:"
  grep -nE '^[A-Za-z_][A-Za-z0-9_]*=' .env | sed -E 's/(=).*/=***REDACTED***/' | head -n 80 || true
else
  fail ".env is missing locally"
fi

section "Docker compose published ports"
if docker compose ps >/tmp/emisiones_compose_ps_136.txt 2>&1; then
  cat /tmp/emisiones_compose_ps_136.txt
  if grep -Eq '0\.0\.0\.0:[0-9]+->5432|\[::\]:[0-9]+->5432' /tmp/emisiones_compose_ps_136.txt; then
    fail "PostgreSQL is published on all interfaces; bind to 127.0.0.1 or remove external port for pilot"
  else
    ok "PostgreSQL is not published on all interfaces"
  fi
  if grep -Eq '0\.0\.0\.0:[0-9]+->6379|\[::\]:[0-9]+->6379' /tmp/emisiones_compose_ps_136.txt; then
    fail "Redis is published on all interfaces; bind to 127.0.0.1 or remove external port for pilot"
  else
    ok "Redis is not published on all interfaces"
  fi
  if grep -Eq '127\.0\.0\.1:[0-9]+->8000' /tmp/emisiones_compose_ps_136.txt; then
    ok "backend is bound to localhost"
  else
    warn "backend binding is not clearly localhost-only; review intended access model"
  fi
else
  fail "docker compose ps failed"
  cat /tmp/emisiones_compose_ps_136.txt 2>/dev/null || true
fi

section "Docker compose config port definitions"
if docker compose config >/tmp/emisiones_compose_config_136.yml 2>&1; then
  awk '
    /^[[:space:]]+[a-zA-Z0-9_-]+:$/ { svc=$1; gsub(":", "", svc) }
    /published:|target:|host_ip:|ports:/ { print NR ":" $0 }
  ' /tmp/emisiones_compose_config_136.yml | head -n 120
else
  warn "docker compose config could not be rendered"
fi

section "Pilot readiness decision"
if [ "$failures" -eq 0 ]; then
  if [ "$warnings" -eq 0 ]; then
    echo "PILOT_ENV_PORTS_READY"
    exit 0
  fi
  echo "PILOT_ENV_PORTS_READY_WITH_WARNINGS"
  echo "Warnings: $warnings"
  exit 0
fi

echo "PILOT_ENV_PORTS_BLOCKED"
echo "Failures: $failures"
echo "Warnings: $warnings"
exit 1
