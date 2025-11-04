# SOLTI Multi-Collection Coordination Repository

This repository serves as the **coordination hub** for the SOLTI (Systems Oriented Laboratory Testing & Integration) Ansible collections ecosystem. Individual collections are maintained in separate GitHub repositories but are integrated and documented here.

## Quick Navigation

| Collection | Purpose | Status | GitHub Repository |
|------------|---------|--------|-------------------|
| **solti-monitoring** | Monitoring stack (Telegraf, InfluxDB, Loki, Alloy) | ✅ Production | [jackaltx/solti-monitoring](https://github.com/jackaltx/solti-monitoring) |
| **solti-containers** | Testing containers (Mattermost, Redis, Elasticsearch, etc.) | ✅ Production | [jackaltx/solti-containers](https://github.com/jackaltx/solti-containers) |
| **solti-ensemble** | Shared services (MariaDB, HashiVault, security tools) | 🚧 Active Development | [jackaltx/solti-ensemble](https://github.com/jackaltx/solti-ensemble) |
| **solti** | Documentation and architecture | 📚 Reference | [./solti/](./solti/) (this repo) |

## What is SOLTI?

**SOLTI** provides a comprehensive framework for testing and integrating system components in controlled environments. The project emphasizes methodical testing, system behavior analysis, and component integration.

- **S**ystems: Managing and testing system-of-systems
- **O**riented: Structured and purposeful approach
- **L**aboratory: Controlled testing environment
- **T**esting: Verification and validation
- **I**ntegration: Component interconnection and interaction

Named after [Sir Georg Solti](https://en.wikipedia.org/wiki/Georg_Solti), renowned for his precise and analytical conducting style.

## Repository Structure

```
jackaltx/
├── README.md                      # This file - navigation hub
├── CLAUDE.md                      # Claude Code context for multi-collection work
├── solti/                         # Documentation collection
│   ├── solti.md                   # Philosophy and development journey
│   ├── Development.md             # Current development diary
│   ├── TestingConcept.md          # Testing methodology
│   └── artifacts/                 # Reference implementations
├── solti-monitoring/              # Monitoring collection (git submodule/local)
├── solti-containers/              # Container services collection
├── solti-ensemble/                # Shared utilities collection
├── solti_*_docs.txt               # Consolidated documentation (310KB total)
└── solti-monitoring.wiki/         # Wiki documentation (test results)
```

## Consolidated Documentation Files

The root directory contains four consolidated documentation files (`*_docs.txt`) that aggregate content from each collection:

- **solti_monitoring_docs.txt** (103KB) - Complete monitoring collection documentation
- **solti_containers_docs.txt** (84KB) - Container services documentation
- **solti_ensemble_docs.txt** (29KB) - Shared utilities documentation
- **solti_docs.txt** (94KB) - Core architecture and philosophy

These files provide AI assistants and developers with comprehensive context about each collection in a single location.

## Getting Started

### For New Users

1. **Want monitoring?** → Start with [solti-monitoring](https://github.com/jackaltx/solti-monitoring)
2. **Want test containers?** → Start with [solti-containers](https://github.com/jackaltx/solti-containers)
3. **Want database/security?** → Start with [solti-ensemble](https://github.com/jackaltx/solti-ensemble)
4. **Want to understand the philosophy?** → Read [solti/solti.md](./solti/solti.md)

### For Developers

Each collection has its own `CLAUDE.md` with collection-specific guidance:
- [Root CLAUDE.md](./CLAUDE.md) - Multi-collection coordination
- [solti-monitoring/CLAUDE.md](./solti-monitoring/CLAUDE.md) - Monitoring specifics
- [solti-containers/CLAUDE.md](./solti-containers/CLAUDE.md) - Container patterns
- [solti-ensemble/CLAUDE.md](./solti-ensemble/CLAUDE.md) - Security and utilities
- [solti/CLAUDE.md](./solti/CLAUDE.md) - Documentation repository

## Common Patterns Across Collections

1. **Molecule Testing** - All collections use molecule for testing
2. **Utility Scripts** - `manage-svc.sh`, `svc-exec.sh` for service management
3. **Verification** - Each role has verification tasks in `verify.yml`
4. **Systemd Integration** - Podman quadlets for container management
5. **Multi-Platform** - Support for Rocky9, Debian12, Ubuntu24

## Integration Points

- **solti-monitoring** depends on **solti-ensemble** for database services
- **solti-monitoring** uses **solti-containers** for testing infrastructure
- All collections share testing patterns and philosophies
- Notifications flow: Tests → Mattermost (solti-containers)
- Test results stored in Elasticsearch (solti-containers)

## Testing Philosophy

Testing is distributed across three platforms in a 3D matrix:

- **3 Distros**: Rocky Linux 9, Debian 12, Ubuntu 24
- **3 Platforms**: Proxmox VE, Podman, GitHub Actions
- **Feature-Based**: Logging, metrics, security verification

Results flow: Local testing → Mattermost notifications → Elasticsearch storage → Wiki reports

## Technology Stack

- **Ansible** - Infrastructure automation
- **Molecule** - Testing framework
- **Podman** - Rootless containers with systemd integration
- **Proxmox VE** - Virtualization platform
- **InfluxDB/Loki** - Metrics and log storage
- **Telegraf/Alloy** - Collection agents

## Development Status

### Current Focus (as of 2025)

- Standardizing reporting flow across collections
- Testing matrix: 3 distros × 3 platforms
- Moving from GIST to Mattermost for notifications
- Elasticsearch for test results storage
- Claude Code MCP integration work starting

## License

MIT-0 - All SOLTI work is freely available without restriction.

## Contact

Use GitHub issues in the respective collection repositories.

## Acknowledgments

- **Sir Georg Solti** - Name inspiration
- **Claude AI** - Development assistant and pair programming partner
- **Open Source Community** - Foundation technologies
