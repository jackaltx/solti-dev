# Report Anonymization Process

## Purpose

Process for anonymizing technical reports before public publication. Ensures no exposure of:
- Internal network topology
- Specific hostnames/domains
- Authentication credentials or paths
- Proprietary naming conventions

## Pre-Publication Checklist

### 1. Hostnames and Domains

**Replace all real hostnames with example domains:**

```bash
# Find potential hostnames
grep -E '[a-z0-9-]+\.(com|net|org|local|internal)' report.md

# Standard replacements:
real-server.yourdomain.com → ispconfig_server.example.com
logs.yourdomain.com → log-collector.example.com
monitor.yourdomain.com → monitor.example.com
```

**Pattern**: Use descriptive role-based names with `example.com` domain.

### 2. IP Addresses

**Private IPs (RFC1918):**
- `10.x.x.x`, `172.16-31.x.x`, `192.168.x.x` ranges

**Decision tree:**
- **Keep if**: Generic example (192.168.1.1, 10.0.0.1)
- **Replace if**: Reveals network topology or VLAN structure

**Common replacements:**
```bash
# Internal monitoring network
10.10.0.11 → 10.0.0.11
10.10.0.1 → 10.0.0.1

# DMZ or specific segments
172.20.5.10 → 172.16.1.10
```

**Public IPs:**
- **Always replace** with example ranges:
  - `192.0.2.0/24` (TEST-NET-1)
  - `198.51.100.0/24` (TEST-NET-2)
  - `203.0.113.0/24` (TEST-NET-3)

### 3. File Paths

**Replace user-specific or revealing paths:**

```bash
# Authentication tokens
~/.secrets/specific-service-operators_token → ~/.secrets/loki_token
~/.secrets/prod-db-password → ~/.secrets/db_password

# Personal paths
/home/username/.claude/plans/ → ~/.claude/plans/
~/.config/mycompany/ → ~/.config/example/

# Plan filenames (auto-generated)
dynamic-honking-manatee.md → descriptive-plan-name.md
bubbly-swimming-tower.md → config-validation-plan.md
```

**Keep generic paths:**
- `/etc/`, `/var/log/`, `/usr/local/`
- System service paths
- Standard config locations

### 4. Credentials and Tokens

**Never include:**
- Actual token values
- API keys
- Passwords (even hashed)
- SSH keys

**Show structure only:**
```bash
# Good - shows method without exposure
TOKEN=$(cat ~/.secrets/loki_token)
curl -H "Authorization: Bearer $TOKEN" ...

# Bad - exposes value
TOKEN="eyJ0eXAiOiJKV1QiLCJhbGc..."
```

### 5. Organizational Information

**Replace or genericize:**
- Company/project-specific naming
- Internal service names (unless generic)
- Team names or internal departments

**Examples:**
```bash
# Service names
acme-prod-db → production-db
mycompany-logging → logging-stack

# Project names
project-phoenix-2024 → monitoring-project
```

### 6. Dates and Timestamps

**Generally safe to keep if:**
- Used as examples (2025-12-29)
- Part of time range demonstration
- No correlation to sensitive events

**Consider removing if:**
- Reveals deployment dates of security fixes
- Shows vulnerability windows
- Correlates with incidents

**Recommendation**: Keep for technical accuracy, remove only if operationally sensitive.

## Anonymization Workflow

### Step 1: Initial Scan

```bash
# Quick scan for common issues
cd articles/reports/

# Find hostnames
grep -E '[a-z0-9-]+\.(com|net|org|local|io)' report.md | grep -v example.com

# Find private IPs
grep -oE '\b10\.[0-9]+\.[0-9]+\.[0-9]+\b' report.md
grep -oE '\b192\.168\.[0-9]+\.[0-9]+\b' report.md
grep -oE '\b172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+\b' report.md

# Find paths to home directory
grep -E '~?/home/[a-z]+/' report.md
grep -E '~/.secrets/' report.md
```

### Step 2: Create Replacement Map

Document planned changes in a temporary file:

```bash
# replacements.txt
OLD → NEW
---
10.10.0.11 → 10.0.0.11
10.10.0.1 → 10.0.0.1
~/.secrets/log-collector-operators_token → ~/.secrets/loki_token
dynamic-honking-manatee.md → loki-filter-analysis.md
```

### Step 3: Apply Replacements

Use Claude Code or manual edits:

```bash
# With Claude Code
# Review file and request: "Anonymize according to replacements.txt"

# Manual sed (use with caution)
sed -i 's/10\.10\.0\.11/10.0.0.11/g' report.md
sed -i 's/10\.10\.0\.1/10.0.0.1/g' report.md
sed -i 's/log-collector-operators_token/loki_token/g' report.md
```

### Step 4: Verification

```bash
# Re-scan for missed items
grep -E '[a-z0-9-]+\.(com|net|org)' report.md | grep -v example.com
grep -oE '\b10\.[0-9]+\.[0-9]+\.[0-9]+\b' report.md | sort -u

# Check for exposed credentials
grep -i "token.*=" report.md
grep -i "password" report.md
grep -i "apikey" report.md
```

### Step 5: Manual Review

**Read through entire report checking:**
- [ ] All hostnames use example.com
- [ ] IP addresses are generic or example ranges
- [ ] No credential values exposed
- [ ] File paths don't reveal personal info
- [ ] Service names are generic
- [ ] Technical accuracy maintained

## Common Patterns

### Loki/Grafana Reports

```bash
# Hostnames
collector.internal.net → log-collector.example.com
monitor.dmz.net → monitor.example.com

# IPs
WireGuard endpoint: 10.10.0.11 → 10.0.0.11
Local binding: 10.10.0.1 → 10.0.0.1

# Tokens
~/.secrets/loki-prod-operators → ~/.secrets/loki_token
~/.secrets/grafana-api-key → ~/.secrets/grafana_token
```

### Ansible/Infrastructure Reports

```bash
# Inventory
prod-web-01.company.net → web-server-01.example.com
db-primary.internal → database-primary.example.com

# Paths
~/ansible/company-infra/ → ~/ansible/infrastructure/
~/.ansible/vault/prod → ~/.ansible/vault/production
```

### Security/Monitoring Reports

```bash
# Service names
splunk.security.internal → siem.example.com
sentry.prod.company.net → error-tracking.example.com

# Alert endpoints
pagerduty-api-key-prod → monitoring_api_key
slack-webhook-security → notification_webhook
```

## Post-Anonymization

### Add Disclaimer

Consider adding to report header:

```markdown
---
**Note**: Hostnames, IP addresses, and file paths have been anonymized for publication.
Technical accuracy is maintained with example domains (example.com) and private IP ranges.
---
```

### Version Control

```bash
# Commit anonymized version
git add articles/reports/anonymized-report.md
git commit -m "docs: add anonymized report for publication"

# Keep original in private branch/location if needed
```

### Publication Checklist

Before publishing:
- [ ] All items from Step 5 verification complete
- [ ] Disclaimer added (if appropriate)
- [ ] Technical accuracy verified
- [ ] No proprietary information exposed
- [ ] File reviewed by second person (optional)

## Quick Reference

| Category | Action | Example |
|----------|--------|---------|
| Hostnames | Replace with example.com | `monitor.example.com` |
| Private IPs | Genericize or use example ranges | `10.0.0.11`, `192.168.1.1` |
| Public IPs | Use TEST-NET ranges | `192.0.2.10` |
| Tokens | Show structure only | `~/.secrets/loki_token` |
| User paths | Use tilde notation | `~/.config/` |
| Plan names | Use descriptive names | `loki-filter-analysis.md` |
| Dates | Keep unless sensitive | `2025-12-29` (OK) |

## Examples

### Before Anonymization
```bash
ssh admin@prod-monitor.acmecompany.com
TOKEN=$(cat ~/.secrets/acme-prod-loki-operator-token-2024)
curl http://10.10.0.11:3100/loki/api/v1/query
```

### After Anonymization
```bash
ssh admin@monitor.example.com
TOKEN=$(cat ~/.secrets/loki_token)
curl http://10.0.0.11:3100/loki/api/v1/query
```

## Automation

Future enhancement - create script:

```bash
#!/bin/bash
# anonymize-report.sh
# Automated anonymization with predefined rules

# Load replacement rules
# Apply systematic changes
# Generate verification report
# Prompt for manual review items
```

## Related Files

- [Server_fail2ban_efficiency.md](reports/Server_fail2ban_efficiency.md) - Example anonymized report
- CLAUDE.md - Project documentation standards
