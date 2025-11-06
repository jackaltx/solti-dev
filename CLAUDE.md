# Solti Multi-Collection Project

## Purpose
This is the root coordination repository for the Solti Ansible collections suite.
Individual collections are maintained in separate repositories but integrated here.

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
- **Location**: ./solti/
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
