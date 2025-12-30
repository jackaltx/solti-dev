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
3. **Alloy config validation** (ref: ~/.claude/plans/bubbly-swimming-tower.md):
   - Test config with `alloy fmt` and `alloy validate` before overwriting
   - Explore live config reload

### Long-term

- Extract orchestrator for public release
- Define standardized Solti collection pattern
- Periodic cleanup of site-specific leakage

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
