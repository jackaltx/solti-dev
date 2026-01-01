# Solti Multi-Collection Project

## Purpose

Root coordination repository for the Solti Ansible collections suite. Individual collections are maintained in separate repositories but integrated here.

## Repository Organization

This is the **root of a larger system** with distinct organizational elements:

- **mylab/** - Orchestrator (run installations from here)
  - Site-specific deployment scripts and configuration
  - Inventory, playbooks, credentials, service tokens

- **solti-*** - Ansible collections (subdirectories)
  - solti-monitoring, solti-containers, solti-ensemble, solti-docs
  - Each collection has its own CLAUDE.md for collection-specific context

- **Reports/** - Analysis outputs
  - Generated reports from evaluation and testing
  - Sprint results, efficiency analysis, validation reports

- **docs/** (if exists) - Process documentation
  - System-wide procedures and methodologies
  - Architectural documentation

### Claude's Role

**Look across the entire system** - not just individual collections. Each element (orchestrator, collections, reports) has agents supporting development and running. Generate reports in Reports/, reference processes in docs/, and coordinate changes across collections.

## Orchestrator (mylab)

The `mylab/` directory contains the orchestrator - tightly-bound code and data that automates deployments across Solti collections. Long-term goal: extract into cleansed reference implementation for public release.

**Orchestrator Components:**

- [manage-svc.sh](mylab/manage-svc.sh) - Service lifecycle (deploy/remove/prepare)
- [svc-exec.sh](mylab/svc-exec.sh) - Task execution (verify/configure)
- [deploy-fleur-workflow.sh](mylab/deploy-fleur-workflow.sh) - Automated workflow with validation
- [inventory.yml](mylab/inventory.yml) - Host registry and configuration
- `mylab/data/` - Service tokens, credentials, configs (site-specific)
- `mylab/playbooks/` - Deployment playbooks (site-specific)

## Reference Machines

### monitor11.a0a0.org

**Type:** Proxmox VM (local infrastructure)
**Purpose:** Production metrics/log collector (solti-monitoring reference, partial deployment)
**Stack:** InfluxDB, Loki, Telegraf, Alloy

**Playbooks:**

- [svc-monitor11-metrics.yml](mylab/playbooks/svc-monitor11-metrics.yml) - InfluxDB + Telegraf
- [svc-monitor11-logs.yml](mylab/playbooks/svc-monitor11-logs.yml) - Loki + Alloy

**Configuration:**

- Telegraf outputs to localhost InfluxDB
- Loki with S3 backend (jacknas2.a0a0.org:8010, bucket: loki11)
- InfluxDB with S3 backend (bucket: influx11, 30d retention)
- WireGuard endpoint for remote collectors (10.10.0.11)

### fleur.lavnet.net

**Type:** Linode VPS (public cloud)
**Purpose:** Full production deployment (complete solti-monitoring reference)
**Stack:** Alloy, Telegraf, ISPConfig, Gitea, Fail2ban, WireGuard client

**Playbooks:**

- [fleur-monitor.yml](mylab/playbooks/fleur-monitor.yml) - Legacy monitoring
- [fleur-alloy.yml](mylab/playbooks/fleur-alloy.yml) - Current Alloy config

**Configuration:**

- Monitors: Apache, ISPConfig, Fail2ban, Gitea, Mail (journald), Bind9 (journald), WireGuard (journald)
- Ships logs to monitor11 via WireGuard (10.10.0.11)
- Ships metrics to monitor11wg
- Alloy args: `--disable-reporting --server.http.listen-addr=127.0.0.1:12345`

## Current Goals

### Short-term

1. ✅ Document reference machines
2. **Site-specific isolation** - mylab is only repo with site-specific info; use example.com in public collections
3. **Alloy config validation**:
   - ALWAYS test before deploy (see workflow below)
   - Explore live config reload

### Alloy Test/Deploy Workflow

**IMPORTANT**: Always test Alloy config changes before deploying!

```bash
# 1. TEST - Validates config and writes to /tmp (does NOT restart service)
cd mylab
ansible-playbook --become-password-file ~/.secrets/lavender.pass \
  ./playbooks/fleur/91-fleur-alloy-test.yml

# 2. DEPLOY - Writes to /etc/alloy/config.alloy and restarts service
cd mylab
ansible-playbook --become-password-file ~/.secrets/lavender.pass \
  ./playbooks/fleur/22-fleur-alloy.yml
```

**Test playbook behavior**:
- Renders config to `/tmp/alloy-test-config-YYYYMMDDTHHMMSS.alloy` on fleur
- Runs `alloy fmt` and `alloy validate` to check syntax
- Does NOT restart alloy service
- Safe to run multiple times

### Long-term

- Extract orchestrator for public release
- Define standardized Solti collection pattern
- Periodic cleanup of site-specific leakage

## Grafana Dashboard Development Workflow

### Overview

Local Grafana instances (running in Podman) can be managed programmatically via the HTTP API. This workflow enables debugging and fixing dashboard panels without manual clicking in the UI.

### Environment Setup

**Local Grafana Access:**

- **Container**: `grafana-infra` or `grafana-svc` on localhost:3000
- **Public URL**: <https://grafana.a0a0.org:8080> (Traefik proxy)
- **Admin Credentials**: `~/.secrets/grafana.admin.pass`
- **API Auth**: `-u admin:$(cat ~/.secrets/grafana.admin.pass)`

**Loki Access:**

- **monitor11**: <http://monitor11.a0a0.org:3100>
- **API endpoint**: `/loki/api/v1/query` (instant), `/loki/api/v1/query_range` (time series)

### Dashboard Debug/Fix Workflow

#### Step 1: Identify the Problem

- User reports "no data" or incorrect data in specific panels
- Note panel names/titles

#### Step 2: Fetch Dashboard JSON

```bash
# Get dashboard by UID
curl -s -u admin:$(cat ~/.secrets/grafana.admin.pass) \
  http://localhost:3000/api/dashboards/uid/fail2ban > /tmp/dashboard.json

# List all panels
python3 << 'EOF'
import json
with open('/tmp/dashboard.json', 'r') as f:
    d = json.load(f)
panels = d['dashboard']['panels']
for p in panels:
    print(f"Panel {p['id']}: {p.get('title', 'No title')}")
    print(f"  Query: {p['targets'][0].get('expr', 'EMPTY')[:80]}")
EOF
```

#### Step 3: Test Queries Directly Against Loki

```python
# Test a Loki query BEFORE deploying to dashboard
import subprocess, json, time

now_ns = int(time.time() * 1e9)
start_ns = now_ns - (24 * 3600 * int(1e9))

query = 'sum by(jail) (count_over_time({service_type="fail2ban"} [24h]))'
cmd = f'curl -s -G "http://monitor11.a0a0.org:3100/loki/api/v1/query" \
  --data-urlencode \'query={query}\' \
  --data-urlencode time={now_ns}'

result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
data = json.loads(result.stdout)

if data['status'] == 'success' and data['data']['result']:
    print(f"✅ Query works! {len(data['data']['result'])} results")
    for res in data['data']['result']:
        print(f"  {res['metric']}: {res['value'][1]}")
else:
    print(f"❌ Query failed: {data.get('error', 'unknown')}")
```

#### Step 4: Fix Dashboard JSON

```python
import json

# Load dashboard
with open('/tmp/dashboard.json', 'r') as f:
    d = json.load(f)
dashboard = d['dashboard']

# Fix specific panel
for panel in dashboard['panels']:
    if panel['id'] == 10:  # Panel ID
        # Update query
        panel['targets'][0]['expr'] = 'your_tested_query_here'
        panel['targets'][0]['queryType'] = 'instant'  # or 'range'
        print(f"✅ Updated panel {panel['id']}")

# Save
with open('/tmp/dashboard-fixed.json', 'w') as f:
    json.dump(dashboard, f, indent=2)
```

#### Step 5: Deploy to Grafana

```python
import json, subprocess

with open('/tmp/dashboard-fixed.json', 'r') as f:
    dashboard = json.load(f)

payload = {
    "dashboard": dashboard,
    "message": "Fix panel X: description of change",
    "overwrite": True
}

with open('/tmp/payload.json', 'w') as f:
    json.dump(payload, f)

cmd = 'curl -s -X POST -H "Content-Type: application/json" \
  -u admin:$(cat ~/.secrets/grafana.admin.pass) \
  -d @/tmp/payload.json \
  http://localhost:3000/api/dashboards/db'

result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
response = json.loads(result.stdout)
print(f"Status: {response.get('status')}")
print(f"Version: {response.get('version')}")
```

#### Step 6: Verify in Browser

- Hard refresh: Ctrl+Shift+R (or Cmd+Shift+R)
- Check that data appears correctly

### Common Loki Query Patterns

**Parsing journald logs:**

```logql
# Extract fields from log message using regexp
{service_type="fail2ban"}
| regexp `\[(?P<jail>[^\]]+)\]\s+(?P<action>Ban|Unban)\s+(?P<banned_ip>\d+\.\d+\.\d+\.\d+)`
| action="Ban"
```

**Instant vs Range queries:**

- **Instant** (`/api/v1/query`): Single value per metric, good for tables
- **Range** (`/api/v1/query_range`): Time series, good for graphs

**Aggregations:**

```logql
# Count by label over time window
sum by(jail) (count_over_time({service_type="fail2ban"} [24h]))

# Top N results
topk(20, sum by(banned_ip) (count_over_time(...)))
```

### Fail2ban Journald Migration (2026-01-01)

**Important**: Fail2ban logs migrated from direct file monitoring to journald.

**OLD source (deprecated):**

- Labels: `{job="fail2ban", action_type="Ban", jail="sshd"}`
- Pre-parsed by log shipper
- Last data: 2026-01-01 04:18 UTC

**NEW source (current):**

- Labels: `{service_type="fail2ban", hostname="fleur.lavnet.net"}`
- Log format: `[jail] Ban/Unban IP`
- Requires regex parsing in queries
- Started: 2026-01-01 04:41 UTC

**Query migration example:**

```logql
# OLD (don't use)
{job="fail2ban", action_type="Ban", jail="sshd"}

# NEW (current)
{service_type="fail2ban"}
| regexp `\[(?P<jail>[^\]]+)\]\s+(?P<action>Ban|Unban)\s+(?P<banned_ip>\d+\.\d+\.\d+\.\d+)`
| action="Ban"
| jail="sshd"
```

### Useful Grafana API Endpoints

```bash
# List all dashboards
curl -s -u admin:$(cat ~/.secrets/grafana.admin.pass) \
  http://localhost:3000/api/search?type=dash-db | python3 -m json.tool

# List datasources
curl -s -u admin:$(cat ~/.secrets/grafana.admin.pass) \
  http://localhost:3000/api/datasources | python3 -m json.tool

# Get dashboard by UID
curl -s -u admin:$(cat ~/.secrets/grafana.admin.pass) \
  http://localhost:3000/api/dashboards/uid/DASHBOARD_UID

# Get organization info
curl -s -u admin:$(cat ~/.secrets/grafana.admin.pass) \
  http://localhost:3000/api/org
```

### Troubleshooting Tips

1. **Check label availability**: `curl http://monitor11.a0a0.org:3100/loki/api/v1/labels`
2. **Check label values**: `curl http://monitor11.a0a0.org:3100/loki/api/v1/label/LABELNAME/values`
3. **Test basic query**: Start with `{service_type="fail2ban"}` before adding filters
4. **Compare old vs new data**: Use `count_over_time()` to see which source has data
5. **Dashboard variables**: Use `$hostname`, `$jail` in queries to enable filtering
6. **Query type matters**: Tables need `instant`, graphs need `range`

## Collection Overview

### solti-monitoring (Active)

- **Purpose**: Monitoring stack (Telegraf, InfluxDB, Loki, Alloy)
- **Status**: Maturing, comprehensive testing
- **Location**: ./solti-monitoring/
- **Key Files**: See solti_monitoring_docs.txt

### solti-containers (Active)

- **Purpose**: Testing containers (Mattermost, Redis, Elasticsearch, etc.)
- **Status**: Active development
- **Location**: ./solti-containers/
- **Key Files**: See solti_containers_docs.txt

### solti-ensemble (Starting)

- **Purpose**: Shared services (MariaDB, HashiVault, ACME)
- **Status**: Early development
- **Location**: ./solti-ensemble/
- **Key Files**: See solti_ensemble_docs.txt

### solti (Documentation)

- **Purpose**: Core documentation and architecture
- **Status**: Reference documentation
- **Location**: ./solti-docs/
- **Key Files**: See solti_docs.txt

## Working with Claude Code

### Key Context Files

- `*_docs.txt` - Consolidated documentation from each collection
- `solti/solti.md` - Overall architecture and philosophy
- Individual `CLAUDE.md` in each collection - Collection-specific context

### Common Patterns Across Collections

1. **Molecule Testing**: All collections use molecule for unit/integration tests
2. **Utility Scripts**: `manage-svc.sh`, `svc-exec.sh` for service management
3. **Verification**: Each role has verification tasks in `verify.yml`
4. **Systemd Integration**: Podman quadlets for container management

### Integration Points

- solti-monitoring depends on solti-ensemble (for database services)
- solti-monitoring uses solti-containers (for testing)
- All collections share testing patterns and philosophies

### Testing Philosophy

From the SOLTI documentation:

- **S**ystems: Managing system-of-systems
- **O**riented: Structured and purposeful
- **L**aboratory: Controlled testing environment
- **T**esting: Verification and validation
- **I**ntegration: Component interconnection

### Secure Logging Pattern

**All collections use `MOLECULE_SECURE_LOGGING` for credential debugging:**

- Default: `true` (credentials/secrets hidden with `no_log`)
- Debug mode: `MOLECULE_SECURE_LOGGING=false` (shows credential details in logs)
- Set in molecule.yml inventory:
  ```yaml
  secure_logging: "{{ lookup('env', 'MOLECULE_SECURE_LOGGING', default='true') | bool }}"
  ```
- Used in tasks with sensitive data:
  ```yaml
  no_log: "{{ secure_logging | default(true) }}"
  ```

**Propagate this pattern to all new roles and collections.**

### Current Development Focus

- Standardizing reporting flow across collections
- Testing matrix: 3 distros (Rocky9, Debian12, Ubuntu24) × 3 platforms (Proxmox, Podman, GitHub)
- Moving from GIST to Mattermost for notifications
- Elasticsearch for test results storage

## Claude Code Integration

Claude Code uses molecule for convergence testing - expect code implementation during development cycles. Ask before making significant architectural changes or adding new dependencies.

**IMPORTANT:** Create git checkpoint commits before every test run. Keep all checkpoints during development for audit trail, squash before PR:

```bash
# During development - commit freely
git add -A && git commit -m "checkpoint: description"
# Run tests, repeat

# Before PR - squash checkpoints
git rebase -i HEAD~N  # N = number of checkpoint commits
```
