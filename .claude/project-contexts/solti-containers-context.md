# SOLTI-CONTAINERS Project Context

**Last Updated**: 2025-11-28
**Status**: Production-ready with active development
**Location**: `./solti-containers/`

## Purpose

This document provides comprehensive context about the **solti-containers** Ansible Galaxy collection. It serves as:
- Reference for understanding the architecture and patterns
- Template for building new collections with similar approaches
- Onboarding guide for contributors and AI assistants

---

## Table of Contents

1. [Project Philosophy](#project-philosophy)
2. [Architecture Overview](#architecture-overview)
3. [Service Catalog](#service-catalog)
4. [Management Scripts](#management-scripts)
5. [Development Patterns](#development-patterns)
6. [Testing Strategy](#testing-strategy)
7. [Integration Points](#integration-points)
8. [Documentation Structure](#documentation-structure)
9. [Current State](#current-state)
10. [Using This as a Template](#using-this-as-a-template)

---

## Project Philosophy

### Core Principles

**Lightweight Over Heavy**: Containers instead of VMs for rapid iteration
**Data Persistence**: Preserve data across deploy/remove cycles
**Iterate Until Right**: Fast feedback loops during development
**Consistent Patterns**: Common functionality via inheritance
**Security First**: Rootless containers, SELinux, automatic SSL

### The SOLTI Acronym
From the parent project:
- **S**ystems: Managing system-of-systems
- **O**riented: Structured and purposeful
- **L**aboratory: Controlled testing environment
- **T**esting: Verification and validation
- **I**ntegration: Component interconnection

### Design Goals

1. **Developer Experience**: Quick to deploy, easy to iterate, safe to experiment
2. **Production Patterns**: Use techniques suitable for production (Quadlets, systemd)
3. **Testability**: Built-in verification, preparing for comprehensive Molecule testing
4. **Observability**: Each service includes management/monitoring interfaces
5. **Security**: Defense in depth (rootless, SELinux, TLS, secrets management)

---

## Architecture Overview

### The Three Pillars

#### 1. Podman Quadlets
**What**: Systemd-native container management using `.container` and `.kube` files

**Why**:
- Native systemd integration (start/stop/restart/status)
- Automatic dependency management
- Proper logging via journald
- No separate orchestration daemon needed

**How**:
```
~/.config/containers/systemd/<service>.container
systemctl --user daemon-reload
systemctl --user start <service>
```

**Key Features**:
- Rootless execution (no root privileges)
- Automatic restart on failure
- Network definitions via `.network` files
- Volume management via `.volume` files

#### 2. Dynamic Playbook Generation
**What**: `manage-svc.sh` generates Ansible playbooks on-the-fly from templates

**Why**:
- Single source of truth (inventory.yml)
- Reduced code duplication
- Easier to maintain consistency
- Debugging-friendly (preserves failed playbooks)

**How**:
```bash
./manage-svc.sh elasticsearch deploy
# Generates: tmp/elasticsearch-deploy.yml
# Executes: ansible-playbook -i inventory.yml -K tmp/elasticsearch-deploy.yml
# On success: removes tmp file
# On failure: preserves for debugging
```

**Template Structure**:
```yaml
- hosts: elasticsearch
  roles:
    - role: elasticsearch
      tags: deploy
```

#### 3. Role Inheritance via _base
**What**: Common functionality centralized in `roles/_base/`

**Why**:
- DRY principle (Don't Repeat Yourself)
- Consistent behavior across all services
- Single place to fix bugs/add features
- Easier testing and maintenance

**What _base Provides**:
- Service user/group creation
- Directory structure setup
- Network creation (ct-net)
- SELinux configuration
- Quadlet deployment patterns
- Systemd service management
- Common verification tasks
- Data cleanup logic

**How Services Use It**:
```yaml
# In role dependencies
dependencies:
  - role: _base
    vars:
      service_name: "{{ redis_service_name }}"
      # ... other vars
```

### Directory Structure

```
solti-containers/
├── roles/
│   ├── _base/                   # Shared functionality
│   │   ├── tasks/
│   │   │   ├── main.yml         # Entry point
│   │   │   ├── user.yml         # Service user creation
│   │   │   ├── directories.yml  # Directory setup
│   │   │   ├── network.yml      # Container network
│   │   │   ├── selinux.yml      # SELinux policies
│   │   │   └── cleanup.yml      # Data removal logic
│   │   ├── templates/
│   │   │   └── quadlet.j2       # Quadlet file template
│   │   └── defaults/
│   │       └── main.yml         # Default variables
│   │
│   └── <service>/               # Individual service role
│       ├── tasks/
│       │   ├── main.yml         # Deploy logic
│       │   ├── verify.yml       # Health checks
│       │   ├── configure.yml    # Post-deploy config
│       │   └── initialize.yml   # Initial setup
│       ├── templates/
│       │   └── <service>.j2     # Service-specific Quadlet
│       ├── defaults/
│       │   └── main.yml         # Service variables
│       ├── meta/
│       │   └── main.yml         # Dependencies on _base
│       └── README.md            # Service documentation
│
├── docs/                        # Architecture documentation
├── tmp/                         # Generated playbooks (debug)
├── manage-svc.sh               # Lifecycle management
├── svc-exec.sh                 # Task execution
├── inventory.yml               # Service configuration
└── ansible.cfg                 # Ansible settings
```

---

## Service Catalog

### Status Legend
- ✅ **READY**: Production-ready, fully tested
- 🚧 **ACTIVE**: Working but needs more testing
- 🔧 **IN DEV**: Under active development
- ❌ **DISABLED**: Broken, not functional

### Services

#### Redis ✅ READY
**Purpose**: Fast key-value store for collecting test reports

**Configuration**:
- Image: `redis:7.2-alpine`
- Ports: 6379 (Redis), 8081 (Commander UI)
- Data: `/var/lib/ct-redis/data`
- Network: `ct-net`

**Features**:
- Password authentication
- LRU eviction policy
- Configurable memory limits
- Redis Commander web UI
- Traefik SSL integration (`redis-ui.a0a0.org`)

**Variables** (from inventory.yml):
```yaml
redis_password: "secure_password"
redis_maxmemory: "256mb"
redis_image: "redis:7.2-alpine"
redis_commander_image: "rediscommander/redis-commander:latest"
```

**Verification**:
```bash
./svc-exec.sh redis verify
# Checks: pod status, Redis ping, Commander UI
```

---

#### Elasticsearch ✅ READY
**Purpose**: Search and analytics engine for logs and test results

**Configuration**:
- Image: `elasticsearch:8.12.1`
- Ports: 9200 (ES), 8088 (Elasticvue UI)
- Data: `/var/lib/ct-elasticsearch/data`
- Memory: 2GB heap default

**Features**:
- X-Pack security
- Optional TLS
- Configurable heap size
- Elasticvue management UI
- Resource limits enforcement

**System Requirements**:
```bash
# Required kernel parameter
sysctl vm.max_map_count=262144
```

**Variables**:
```yaml
elasticsearch_password: "elastic_password"
elasticsearch_heap_size: "2g"
elasticsearch_enable_tls: false
```

**Verification**:
```bash
./svc-exec.sh elasticsearch verify
# Checks: cluster health, index creation, UI access
```

---

#### HashiVault ✅ READY
**Purpose**: Comprehensive secrets management

**Configuration**:
- Image: `hashicorp/vault:1.15`
- Ports: 8200 (API), 8201 (cluster)
- Data: `/var/lib/ct-hashivault/{data,logs}`
- Storage: File backend or Raft

**Features**:
- Auto-unseal capability
- KV v2 secrets engine
- PKI secrets engine
- SSH secrets engine
- Extensive initialization tasks
- Backup/restore procedures

**Management**:
```bash
./svc-exec.sh -K hashivault initialize  # First-time setup
./svc-exec.sh hashivault configure      # Enable engines
./svc-exec.sh -K hashivault backup      # Backup secrets
```

**Secrets Storage**:
- Unseal keys: `~/.secrets/vault-secrets/`
- Root token: `~/.secrets/vault-secrets/root-token`

**Variables**:
```yaml
vault_storage_type: "file"  # or "raft"
vault_enable_tls: false
vault_kv_engine: "kv"
```

---

#### Mattermost ✅ READY
**Purpose**: Private notification collector and test result aggregation

**Configuration**:
- Images: `mattermost-team-edition:latest`, `postgres:13-alpine`
- Port: 8065
- Architecture: Pod with 2 containers (app + DB)
- Data: `/var/lib/ct-mattermost/{data,postgres,config,logs}`

**Features**:
- PostgreSQL backend
- Optional TLS
- Admin user auto-creation
- Team/channel setup automation
- Future MCP integration planned

**Post-Deploy**:
```bash
./svc-exec.sh mattermost configure
# Creates admin user, team, channels
```

**Variables**:
```yaml
mattermost_admin_username: "admin"
mattermost_admin_password: "admin_password"
mattermost_admin_email: "admin@example.com"
postgres_password: "db_password"
```

**Integration**:
- Replacing GIST for notifications
- Webhook receiver for test results
- Claude MCP integration (planned)

---

#### Traefik ✅ READY
**Purpose**: HTTP reverse proxy with automatic Let's Encrypt SSL

**Configuration**:
- Image: `traefik:latest`
- Ports: 8080 (HTTP), 8443 (HTTPS), 9999 (dashboard)
- Certificates: `/var/lib/ct-traefik/letsencrypt`
- Config: Dynamic via container labels

**Features**:
- Automatic SSL termination for all services
- Let's Encrypt ACME challenges
- HTTP → HTTPS redirect
- Dashboard for monitoring
- Wildcard DNS support

**Prerequisites**:
```bash
# DNS requirement
*.a0a0.org → <host_ip>
```

**How It Works**:
1. Service defines Traefik labels in Quadlet
2. Traefik detects labels automatically
3. Requests SSL cert from Let's Encrypt
4. Terminates SSL, forwards HTTP to service

**Example Label Usage** (from Redis):
```ini
Label=traefik.enable=true
Label=traefik.http.routers.redis-ui.rule=Host(`redis-ui.a0a0.org`)
Label=traefik.http.routers.redis-ui.entrypoints=websecure
Label=traefik.http.routers.redis-ui.tls.certresolver=le
```

**Variables**:
```yaml
domain: "a0a0.org"
lets_encrypt_email: "admin@example.com"
```

---

#### MinIO ✅ READY
**Purpose**: S3-compatible object storage for test artifacts

**Configuration**:
- Image: `minio/minio:latest`
- Ports: 9000 (API), 9001 (console)
- Data: `/var/lib/ct-minio/data`

**Features**:
- S3 API compatibility
- Web console
- Access/secret key authentication
- Bucket management
- Multi-user support

**Variables**:
```yaml
minio_root_user: "minioadmin"
minio_root_password: "minioadmin_password"
minio_console_port: 9001
minio_api_port: 9000
```

**Verification**:
```bash
./svc-exec.sh minio verify
# Checks: API health, console access, bucket operations
```

---

#### InfluxDB3 🔧 IN DEVELOPMENT
**Purpose**: Time-series database for metrics collection

**Configuration**:
- Image: `influxdb:latest` (v3.x core)
- Port: 8181
- Data: `/var/lib/ct-influxdb3/data`

**Current Status**:
- Implementation complete
- Testing in progress
- Token generation flow refined

**Deployment Flow**:
1. Deploy with `--without-auth`
2. Generate admin token offline (podman exec)
3. Restart with `--admin-token-file`

**Variables**:
```yaml
influxdb3_admin_token: "admin_token_value"
influxdb3_org: "my-org"
influxdb3_bucket: "my-bucket"
```

**Session State**: See `INFLUXDB3_SESSION_STATE.md` for current work

---

#### Grafana 🚧 ACTIVE
**Purpose**: Monitoring dashboards and visualization

**Status**: Role exists, needs final verification

---

#### Gitea 🚧 ACTIVE
**Purpose**: Git service with web interface

**Status**: Role exists, needs final verification

---

#### Wazuh ❌ DISABLED
**Purpose**: Security monitoring (SIEM/XDR)

**Status**: Broken - containers start but don't stay up, communication issues

**Notes**: Will likely be removed in next version

---

## Management Scripts

### manage-svc.sh

**Purpose**: Service lifecycle management via dynamic playbook generation

**Signature**:
```bash
./manage-svc.sh <service> <action>
```

**Actions**:
- `prepare` - One-time system setup (directories, SELinux, sysctl)
- `deploy` - Deploy and start containers
- `remove` - Stop and remove containers (data preserved by default)

**Features**:
- Always prompts for sudo (`-K` built-in)
- Generates playbooks from templates
- Preserves failed playbooks in `tmp/` for debugging
- Auto-cleans successful playbooks
- Uses inventory.yml for configuration

**Why Sudo?**:
1. Containers create files with elevated ownership
2. Enables data preservation across cycles
3. Critical for "iterate until right" workflow

**Examples**:
```bash
# First-time setup
./manage-svc.sh redis prepare
./manage-svc.sh redis deploy

# Iterate on configuration
vim inventory.yml  # Change redis_maxmemory
./manage-svc.sh redis remove
./manage-svc.sh redis deploy

# Remove including data
DELETE_DATA=true ./manage-svc.sh redis remove
```

**Template Structure**:
```yaml
# Generated playbook structure
---
- hosts: {{ service }}
  become: false
  roles:
    - role: {{ service }}
      tags: {{ action }}
```

**Supported Services**:
elasticsearch, hashivault, redis, mattermost, traefik, minio, wazuh, grafana, gitea, influxdb3

---

### svc-exec.sh

**Purpose**: Execute specific task files for services

**Signature**:
```bash
./svc-exec.sh [-K] <service> [entry]
```

**Parameters**:
- `-K` - Prompt for sudo (optional, for privileged operations)
- `service` - Service name
- `entry` - Task file name (default: `verify`)

**Common Task Files**:
- `verify.yml` - Health checks and functionality tests
- `configure.yml` - Post-deployment configuration
- `initialize.yml` - Initial setup (HashiVault, InfluxDB3)
- `backup.yml` - Data backup procedures
- `restore.yml` - Data restoration

**Examples**:
```bash
# Verification (no sudo)
./svc-exec.sh elasticsearch verify
./svc-exec.sh redis verify

# Configuration (may need sudo)
./svc-exec.sh mattermost configure
./svc-exec.sh -K hashivault initialize

# Maintenance (usually needs sudo)
./svc-exec.sh -K hashivault backup
./svc-exec.sh -K elasticsearch restore
```

**Task File Location**:
```
roles/<service>/tasks/<entry>.yml
```

**Playbook Generation**:
```yaml
# Generated execution playbook
---
- hosts: {{ service }}
  become: false
  tasks:
    - name: "Execute {{ entry }} tasks"
      ansible.builtin.include_role:
        name: {{ service }}
        tasks_from: {{ entry }}
```

---

## Development Patterns

### Creating a New Service

Follow the **Solti-Container-Pattern** (docs/Solti-Container-Pattern.md)

#### 1. Create Role Structure
```bash
mkdir -p roles/newservice/{tasks,templates,defaults,meta}
touch roles/newservice/{tasks/main.yml,defaults/main.yml,meta/main.yml,README.md}
```

#### 2. Define Dependencies
**File**: `roles/newservice/meta/main.yml`
```yaml
dependencies:
  - role: _base
    vars:
      service_name: "{{ newservice_service_name }}"
      service_user: "{{ newservice_user }}"
      service_group: "{{ newservice_group }}"
      base_dir: "{{ newservice_base_dir }}"
      data_dirs: "{{ newservice_data_dirs }}"
      config_dirs: "{{ newservice_config_dirs }}"
      network_name: "{{ newservice_network_name }}"
```

#### 3. Set Defaults
**File**: `roles/newservice/defaults/main.yml`
```yaml
# Service identification
newservice_service_name: ct-newservice
newservice_user: svc-newservice
newservice_group: svc-newservice

# Directories
newservice_base_dir: "/var/lib/{{ newservice_service_name }}"
newservice_data_dirs:
  - "{{ newservice_base_dir }}/data"
newservice_config_dirs:
  - "{{ newservice_base_dir }}/config"

# Network
newservice_network_name: ct-net

# Container image
newservice_image: "newservice:latest"
newservice_port: 8080

# Configuration
newservice_enable_feature: true
```

#### 4. Create Quadlet Template
**File**: `roles/newservice/templates/newservice.container.j2`
```ini
[Unit]
Description=New Service Container
After=network-online.target

[Container]
ContainerName={{ newservice_service_name }}
Image={{ newservice_image }}
Network={{ newservice_network_name }}

# Volumes
Volume={{ newservice_base_dir }}/data:/data:z,U
Volume={{ newservice_base_dir }}/config:/config:z

# Ports
PublishPort={{ newservice_port }}:8080

# Environment
Environment=SERVICE_OPTION=value

# Security
User={{ newservice_user }}
Group={{ newservice_group }}

# Traefik labels (optional)
{% if newservice_enable_traefik | default(false) %}
Label=traefik.enable=true
Label=traefik.http.routers.newservice.rule=Host(`newservice.{{ domain }}`)
Label=traefik.http.routers.newservice.entrypoints=websecure
Label=traefik.http.routers.newservice.tls.certresolver=le
{% endif %}

[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=default.target
```

#### 5. Implement Main Tasks
**File**: `roles/newservice/tasks/main.yml`
```yaml
---
- name: Deploy New Service quadlet
  ansible.builtin.template:
    src: newservice.container.j2
    dest: "~/.config/containers/systemd/{{ newservice_service_name }}.container"
    mode: '0644'
  when: "'deploy' in ansible_run_tags"

- name: Reload systemd user daemon
  ansible.builtin.systemd:
    daemon_reload: true
    scope: user
  when: "'deploy' in ansible_run_tags"

- name: Start New Service
  ansible.builtin.systemd:
    name: "{{ newservice_service_name }}"
    state: started
    enabled: true
    scope: user
  when: "'deploy' in ansible_run_tags"

- name: Stop New Service
  ansible.builtin.systemd:
    name: "{{ newservice_service_name }}"
    state: stopped
    enabled: false
    scope: user
  when: "'remove' in ansible_run_tags"
  ignore_errors: true

- name: Remove quadlet file
  ansible.builtin.file:
    path: "~/.config/containers/systemd/{{ newservice_service_name }}.container"
    state: absent
  when: "'remove' in ansible_run_tags"
```

#### 6. Create Verification Tasks
**File**: `roles/newservice/tasks/verify.yml`
```yaml
---
- name: Check service status
  ansible.builtin.systemd:
    name: "{{ newservice_service_name }}"
    scope: user
  register: service_status

- name: Display service status
  ansible.builtin.debug:
    msg: "{{ newservice_service_name }} is {{ service_status.status.ActiveState }}"

- name: Wait for service to be ready
  ansible.builtin.uri:
    url: "http://localhost:{{ newservice_port }}/health"
    status_code: 200
  register: result
  until: result.status == 200
  retries: 10
  delay: 3

- name: Test basic functionality
  ansible.builtin.uri:
    url: "http://localhost:{{ newservice_port }}/api/test"
    method: POST
    body_format: json
    body:
      test: "data"
    status_code: [200, 201]
  register: test_result

- name: Show test result
  ansible.builtin.debug:
    var: test_result.json
```

#### 7. Update Inventory
**File**: `inventory.yml`
```yaml
all:
  children:
    newservice:
      hosts:
        localhost:
          ansible_connection: local
      vars:
        newservice_image: "newservice:1.0"
        newservice_port: 8080
        newservice_enable_traefik: true
```

#### 8. Update manage-svc.sh
Add service to supported list:
```bash
case "$SERVICE" in
    elasticsearch|hashivault|redis|mattermost|traefik|minio|newservice)
        # ... existing code
        ;;
esac
```

#### 9. Test the Service
```bash
# Prepare system
./manage-svc.sh newservice prepare

# Deploy
./manage-svc.sh newservice deploy

# Verify
./svc-exec.sh newservice verify

# Check logs
journalctl --user -u ct-newservice -f

# Iterate
vim inventory.yml
./manage-svc.sh newservice remove
./manage-svc.sh newservice deploy
```

#### 10. Document
**File**: `roles/newservice/README.md`
```markdown
# New Service Role

## Purpose
Brief description of what this service does.

## Features
- Feature 1
- Feature 2

## Configuration Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `newservice_port` | 8080 | Service port |

## Usage
```bash
./manage-svc.sh newservice prepare
./manage-svc.sh newservice deploy
./svc-exec.sh newservice verify
```

## Troubleshooting
Common issues and solutions.
```

### Check Upgrade Pattern

**Generic container image update checker** - centralized in `_base` role:

```bash
./svc-exec.sh -h <host> -i inventory/<host>.yml <service> check_upgrade
```

**How it works**:
1. Auto-discovers all containers in pod via `service_properties.root`
2. Gets current image ID from running container
3. Pulls latest image from registry
4. Compares image IDs to detect updates
5. Reports per-container and summary status

**Key features**:
- No shell access required in containers (uses podman on host)
- Works with single or multi-container pods
- Skips infra/pause containers automatically
- Sets `container_checks` fact for programmatic use

**Implementation**:
- `_base/tasks/check_upgrade.yml` - Main orchestrator
- `_base/tasks/check_upgrade_container.yml` - Per-container checker
- Service role: Simple wrapper that includes _base implementation

See [docs/Check-Upgrade-Pattern.md](../solti-containers/docs/Check-Upgrade-Pattern.md) for details.

---

### Lifecycle Management Patterns

#### DELETE_DATA Environment Variable

Controls data persistence during service removal:

```bash
# Default: preserve data directories
./manage-svc.sh <service> remove

# Remove data directories completely
DELETE_DATA=true ./manage-svc.sh <service> remove
```

Implemented via `service_properties.delete_data` in all roles. See [docs/Delete-Data-Refactoring.md](../solti-containers/docs/Delete-Data-Refactoring.md).

#### DELETE_IMAGES Environment Variable

Controls container image removal during service removal:

```bash
# Default: keep container images
./manage-svc.sh <service> remove

# Remove container images (forces fresh pull on next deploy)
DELETE_IMAGES=true ./manage-svc.sh <service> remove

# Complete removal (both data and images)
DELETE_DATA=true DELETE_IMAGES=true ./manage-svc.sh <service> remove
```

**Use cases**:
- Fresh install testing
- Forcing image upgrades
- CI/CD pipeline testing
- Troubleshooting image corruption

Supports both single-image and multi-image services (redis, elasticsearch, mattermost).

#### NOPASSWD Auto-Detection

Scripts automatically detect if sudo requires password:

```bash
# No need to specify -K if NOPASSWD configured
./manage-svc.sh <service> deploy

# Scripts test with 'sudo -n true' and only use -K when needed
```

---

### Common Patterns

#### Volume Mounts with Permissions
```ini
# Data that container writes to
Volume=/path/on/host:/path/in/container:z,U

# Read-only config
Volume=/path/on/host:/path/in/container:z,ro

# Secrets (no U flag to preserve perms)
Volume=/path/on/host:/path/in/container:z
```

**Flags**:
- `z` - SELinux relabeling (required on Fedora/RHEL)
- `U` - Chown to container UID (for writable volumes)
- `ro` - Read-only mount

#### Multi-Container Pods
```yaml
# Create kube YAML template
- name: Generate pod definition
  ansible.builtin.template:
    src: newservice-pod.yml.j2
    dest: "{{ newservice_base_dir }}/pod.yml"

# Deploy as quadlet
- name: Deploy pod quadlet
  ansible.builtin.template:
    src: newservice.kube.j2
    dest: "~/.config/containers/systemd/{{ newservice_service_name }}.kube"
```

**Pod Quadlet**:
```ini
[Kube]
Yaml={{ newservice_base_dir }}/pod.yml
Network={{ newservice_network_name }}
```

#### Post-Deploy Configuration
```yaml
# tasks/configure.yml
---
- name: Wait for service
  ansible.builtin.uri:
    url: "http://localhost:{{ newservice_port }}"
    status_code: 200
  retries: 30
  delay: 2

- name: Create admin user
  ansible.builtin.uri:
    url: "http://localhost:{{ newservice_port }}/api/users"
    method: POST
    body_format: json
    body:
      username: "{{ newservice_admin_user }}"
      password: "{{ newservice_admin_password }}"
```

#### Initialization with Secrets
```yaml
# tasks/initialize.yml
---
- name: Generate secret token
  ansible.builtin.set_fact:
    admin_token: "{{ lookup('password', '/dev/null length=32 chars=ascii_letters,digits') }}"

- name: Store token locally
  ansible.builtin.copy:
    content: "{{ admin_token }}"
    dest: "~/.secrets/newservice-token"
    mode: '0600'

- name: Initialize service
  ansible.builtin.command:
    cmd: >
      podman exec {{ newservice_service_name }}
      /app/init --token {{ admin_token }}
```

---

## Testing Strategy

### Current Approach: Task-Based Verification

Each service includes `tasks/verify.yml` for manual testing:
```bash
./svc-exec.sh <service> verify
```

**Typical Verification Steps**:
1. Check systemd service status
2. Wait for service readiness (health endpoint)
3. Test basic API functionality
4. Verify data persistence
5. Check integration points (network, volumes)

### Lifecycle Test Documentation

**Pattern**: Executable test documentation in `roles/<service>/docs/LIFECYCLE-TESTS.md`

**Purpose**: Document complete deployment workflows that can be executed by AI agents or humans

**Structure**:
- **Test 1: Fresh Install** - Complete removal and reinstall with current images
- **Test 2: Upgrade Test** - Check for updates and upgrade workflow
- **Test 3: Integration Tests** - Service-specific integration (e.g., Traefik)

**Key Features**:
- Step-by-step commands with expected outcomes
- Verification commands for manual checking
- Expected duration for each test
- Troubleshooting common issues
- CI/CD integration examples

**Example**: [roles/grafana/docs/LIFECYCLE-TESTS.md](../solti-containers/roles/grafana/docs/LIFECYCLE-TESTS.md)

**Current Coverage**:
- ✅ Grafana - Complete lifecycle test documentation
- 🚧 Gitea - Full Redeploy section in README
- 🚧 InfluxDB3 - Full Redeploy section in README
- 🚧 Mattermost - Full Redeploy section in README

**Benefits**:
- Reproducible testing procedures
- AI agent can execute tests autonomously
- Documents expected behavior
- Foundation for automated CI/CD testing

### Planned: Molecule Integration

**Status**: Strategy documented (`molecule-strategy.md`), not yet implemented

**Goals**:
- Automated testing across platforms
- Consistent test environments
- Integration with CI/CD

**Testing Matrix**:
- **Platforms**: Rocky9, Debian12, Ubuntu24
- **Environments**: Proxmox, Podman, GitHub Actions
- **Scenarios**: default, with-tls, multi-node

**Molecule Structure** (planned):
```
roles/<service>/
└── molecule/
    ├── default/
    │   ├── molecule.yml       # Platform config
    │   ├── converge.yml       # Deploy playbook
    │   ├── verify.yml         # Test assertions
    │   └── destroy.yml        # Cleanup
    └── with-tls/
        └── ... (TLS-enabled variant)
```

**Current Blocker**: Focus on service implementation before comprehensive testing framework

---

## Integration Points

### Shared Network: ct-net

All services use `ct-net` for inter-service communication:
```ini
Network=ct-net
```

**Created by**: `_base` role during prepare phase
**Type**: Podman bridge network
**DNS**: 1.1.1.1, 8.8.8.8

**Service Discovery**:
- Containers reference each other by name
- Example: `http://ct-elasticsearch:9200`

### Traefik SSL Integration

Services enable Traefik via Quadlet labels:
```ini
Label=traefik.enable=true
Label=traefik.http.routers.myservice.rule=Host(`myservice.{{ domain }}`)
Label=traefik.http.routers.myservice.entrypoints=websecure
Label=traefik.http.routers.myservice.tls.certresolver=le
Label=traefik.http.services.myservice.loadbalancer.server.port=8080
```

**Prerequisites**:
1. Traefik deployed first
2. Wildcard DNS: `*.domain` → host IP
3. Ports 80/443 accessible for ACME challenges

### HashiVault Secrets (Planned)

**Current**: Services use inventory.yml for secrets
**Future**: Integration with HashiVault for secret storage

**Planned Pattern**:
```yaml
- name: Get password from Vault
  ansible.builtin.set_fact:
    service_password: "{{ lookup('hashi_vault', 'secret=kv/services/myservice:password') }}"
```

### Data Flow Architecture

**Test Results Flow**:
1. Tests run → generate results
2. Results pushed to **Redis** (fast collection)
3. **Elasticsearch** indexes for search/analysis
4. **Mattermost** receives notifications
5. **MinIO** stores artifacts (logs, screenshots)
6. **Grafana** visualizes metrics

---

## Documentation Structure

### Root Level Documentation

| File | Purpose |
|------|---------|
| `README.md` | Project overview, quick start |
| `CLAUDE.md` | Claude Code context and commands |
| `Container-Role-Architecture.md` | Three pillars explained |
| `molecule-strategy.md` | Testing strategy (not implemented) |
| `podman-quadlet-article.md` | Quadlet deep dive |
| `solti_containers_docs.txt` | Consolidated parent docs |

### docs/ Directory

| File | Purpose |
|------|---------|
| `Solti-Container-Pattern.md` | New service creation guide |
| `TLS-Architecture-Decision.md` | TLS strategy and Traefik |
| `Delete-Data-Refactoring.md` | Data persistence approach |
| `Container-Mount-Options.md` | Volume mounts and SELinux |
| `ansible-tips.md` | Ansible patterns |
| `Claude-code-review.md` | Code review findings |

### Per-Role Documentation

Each role has `roles/<service>/README.md` with:
- Service description
- Features list
- Configuration variables
- Example usage
- Troubleshooting

### Session State Files

Development sessions create state files:
- `DEPLOYMENT_SESSION_STATE.md` - Session continuity
- `INFLUXDB3_SESSION_STATE.md` - Current work status
- `INFLUXDB3_IMPLEMENTATION_PLAN.md` - Design specs

---

## Current State

### Production Ready (6 services)
✅ **redis** - Fully tested, in use
✅ **elasticsearch** - Fully tested, in use
✅ **hashivault** - Fully tested, comprehensive features
✅ **mattermost** - Fully tested, notification receiver
✅ **traefik** - Fully tested, SSL working
✅ **minio** - Fully tested, artifact storage

### Active Development (3 services)
🚧 **grafana** - Role complete, needs verification
🚧 **gitea** - Role complete, needs verification
🔧 **influxdb3** - Implementation done, testing in progress

### Known Issues

**Wazuh** ❌:
- Containers start but don't stay up
- Inter-container communication broken
- Will likely be removed

**Molecule Testing**:
- Strategy documented
- Not yet implemented
- Prioritized after service completion

**VSCode Terminal Limitations**:
- Cannot handle interactive sudo prompts
- Workaround: Use tmux for ansible-playbook runs

### Recent Development

**CI Workflow Simplification** (2025-11-28):
- Archived full molecule CI workflow for future use
- Current CI: lint-only (yamllint, ansible-lint, markdownlint)
- Branch-conditional strictness (strict on main, warnings on test)
- Incremental lint remediation workflow established
- ~92% noise reduction via configuration tuning

**Lifecycle Management Features** (2025-11-20):
- DELETE_IMAGES support added to all services
- Multi-image support (redis, elasticsearch, mattermost)
- NOPASSWD auto-detection in scripts
- Comprehensive lifecycle test documentation pattern
- Full Redeploy docs for gitea, grafana, influxdb3

**Check Upgrade Pattern** (2025-11-20):
- Generic container image update checker
- Centralized in _base role
- Auto-discovers all containers in pod
- Works without shell access in containers
- Rolled out to mattermost, redis (template for all services)

**InfluxDB3 Implementation** (2025-11-09):
- Two-phase auth flow implemented
- Volume mount strategy refined (`:z,U` patterns)
- Offline token generation via `podman exec`
- Testing phase, final verification pending

**Architectural Decisions**:
- TLS centralized via Traefik (not per-service)
- Data preservation via sudo + ownership handling
- SELinux integration via `z` flag on all mounts
- Lint remediation: incremental fixes on test branch, zero errors on main

---

## Using This as a Template

### For New Galaxy Collections

This project demonstrates patterns suitable for:
- Service deployment collections
- Container orchestration roles
- Development environment automation
- Testing infrastructure

### Key Patterns to Replicate

1. **_base Role Pattern**
   - Centralizes common functionality
   - Reduces duplication
   - Eases maintenance

2. **Dynamic Playbook Generation**
   - Single source of truth (inventory)
   - Template-based generation
   - Debug-friendly (preserves failures)

3. **Quadlet-First Design**
   - Systemd-native container management
   - No separate orchestration daemon
   - Production-appropriate patterns

4. **Verification Built-In**
   - Each role has `verify.yml`
   - Executable via `svc-exec.sh`
   - Foundation for Molecule tests

5. **Documentation Strategy**
   - Root-level architecture docs
   - Per-role usage docs
   - Session state for continuity

### What to Adapt

**Service-Specific**:
- Change `ct-*` prefix to your collection's prefix
- Update network name (`ct-net` → `<your>-net`)
- Modify base directory pattern (`/var/lib/ct-*` → `/var/lib/<your>-*`)

**Integration Points**:
- Replace Traefik if using different proxy
- Adapt secrets management to your approach
- Modify service discovery if not using Podman networks

**Testing**:
- Implement Molecule following `molecule-strategy.md`
- Adapt verification tasks to your services
- Add integration tests for your specific use case

### Starting a New Collection

```bash
# Initialize collection structure
ansible-galaxy collection init yournamespace.yourcollection

# Create base structure
cd yournamespace/yourcollection/
mkdir -p roles/_base/{tasks,templates,defaults}
mkdir -p docs
mkdir -p tmp

# Copy pattern files
cp /path/to/solti-containers/roles/_base/* roles/_base/
cp /path/to/solti-containers/manage-svc.sh .
cp /path/to/solti-containers/svc-exec.sh .

# Adapt to your needs
# 1. Update service prefix in _base role
# 2. Update network name
# 3. Create your first service role
# 4. Update scripts with your service list

# Start with one service
mkdir -p roles/yourservice/{tasks,templates,defaults,meta}
# Follow pattern from this document
```

---

## Additional Resources

### External Documentation
- [Podman Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [SELinux Container Labeling](https://www.redhat.com/en/blog/container-selinux-separation)

### Within This Repository
- `docs/Solti-Container-Pattern.md` - Detailed pattern guide
- `Container-Role-Architecture.md` - Architecture deep dive
- `podman-quadlet-article.md` - Quadlet technology explained
- Per-role READMEs for service-specific details

### Parent Project Context
- `../solti/solti.md` - SOLTI philosophy and architecture
- `../solti-monitoring/` - Monitoring stack using similar patterns
- `../solti-ensemble/` - Shared services coordination

---

## Changelog

**2025-11-28**: CI workflow simplified to lint-only, incremental remediation workflow
**2025-11-20**: DELETE_IMAGES feature, NOPASSWD auto-detection, lifecycle test docs
**2025-11-20**: Check upgrade pattern centralized in _base role
**2025-11-10**: Initial context document created
**2025-11-09**: InfluxDB3 implementation completed, DELETE_DATA refactoring
**2025-11**: Traefik SSL integration standardized
**2025-10**: Core architecture stabilized (3 pillars)
**2025-09**: First production services (Redis, Elasticsearch, HashiVault)

---

## Contact and Contribution

This is a personal development project within the larger SOLTI suite. When working with Claude Code or other AI assistants, provide this context document to ensure consistent patterns and architectural alignment.

**Key Principle**: Ask before making significant architectural changes or adding new dependencies. The patterns here are deliberate and support specific workflows.
