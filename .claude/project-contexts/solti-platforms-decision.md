# SOLTI-PLATFORMS: Architectural Decision and Design

**Date**: 2025-11-10
**Status**: Decision approved, ready for implementation
**Type**: New collection creation
**Updated**: 2025-11-10 - Added real implementation examples and revised conductor definition

## Executive Summary

**Decision**: Create new `solti-platforms` collection for VM and K3s cluster management, separate from existing collections.

**Why**: Clear architectural gap exists between orchestration (conductor) and application services (monitoring/containers/ensemble). Platform management represents creating the compute environments where applications run.

**Use Cases**:
- Proxmox VM template building and provisioning
- Linode cloud instance management
- K3s cluster deployment on Raspberry Pi farm
- Custom OS provisioning (ISPConfig, Wazuh server, others)
- Testing environment creation for solti-monitoring

**Evidence**: User has existing Proxmox template build scripts and Linode provisioning playbook - both are platform creation workflows that belong in this collection.

---

## Table of Contents

1. [The Question](#the-question)
2. [Real-World Implementation Examples](#real-world-implementation-examples)
3. [SOLTI Ecosystem Architecture](#solti-ecosystem-architecture)
4. [Analysis: Expand vs. New Collection](#analysis-expand-vs-new-collection)
5. [solti-ensemble Investigation](#solti-ensemble-investigation)
6. [The Revised Architecture Model](#the-revised-architecture-model)
7. [Technology Comparison](#technology-comparison)
8. [Platform Pattern: CREATE → PROVISION](#platform-pattern-create--provision)
9. [Proposed solti-platforms Structure](#proposed-solti-platforms-structure)
10. [Use Case Examples](#use-case-examples)
11. [Integration Points](#integration-points)
12. [First Role: proxmox_template](#first-role-proxmox_template)
13. [Next Steps](#next-steps)

---

## The Question

**Original Ask**: "I want to spin up, configure, destroy VMs on Linode and Proxmox. Proxmox must work first. I want to build OS templates for testing the solti-monitoring project. Should I expand solti-containers or create a new collection?"

**Expanded Scope**:
- K3s cluster deployment on Raspberry Pi farm
- Build templates for Rocky 9.x, Rocky 10.x, Debian 12
- ISPConfig server provisioning
- Wazuh server deployment

**Key Clarification**: "conductor to me are the inventory files and main specialized applications. Proxmox management part of vm stuff."

---

## Real-World Implementation Examples

User has existing platform creation code showing exactly what solti-platforms should do:

### Example 1: Proxmox Template Building

**File**: `build_templates_original/build-rocky9-cloud-init.sh`

```bash
#!/bin/bash
VMID=7000
STORAGE=local-lvm

# Download cloud image
wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2
qemu-img resize Rocky-9-GenericCloud.latest.x86_64.qcow2 8G

# Create VM with specific hardware
sudo qm create $VMID --name "rocky9-template" --ostype l26 \
    --memory 4096 --balloon 1 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --cores 4 --numa 1 \
    --vga serial0 --serial0 socket  \
    --net0 virtio,bridge=vmbr0,mtu=1

# Import disk and configure
sudo qm importdisk $VMID Rocky-9-GenericCloud.latest.x86_64.qcow2 $STORAGE
sudo qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
sudo qm set $VMID --boot order=virtio0
sudo qm set $VMID --scsi1 $STORAGE:cloudinit

# cloud-init configuration
sudo qm set $VMID --tags rocky-template,rocky9,cloudinit
sudo qm set $VMID --ciuser $USER
sudo qm set $VMID --sshkeys ~/.ssh/authorized_keys
sudo qm set $VMID --ipconfig0 ip=dhcp

# Convert to template
sudo qm template $VMID
```

**What it does**: Downloads cloud image → creates VM → configures hardware → sets up cloud-init → converts to template

**File**: `build_templates_original/build-deb12-cloud-init.sh`
- Same pattern for Debian 12 (VMID 9001)
- Shows distribution-specific handling

### Example 2: Linode Instance Creation and Provisioning

**File**: `build_templates_original/fleur-create.yml`

**Play 1: Create Instance (runs on localhost)**
```yaml
- name: Create Linode and run initial setup
  hosts: localhost
  tasks:
    - name: Create Linode instance
      linode.cloud.instance:
        api_token: "{{ linode_token }}"
        label: fleur
        type: g6-standard-2
        region: us-central
        image: linode/debian12
        root_pass: "{{ linode_password }}"
        state: present
      register: linode_instance

    - name: Add new instance to inventory
      add_host:
        name: "{{ linode_instance.instance.ipv4[0] }}"
        groups: new_linode
        ansible_user: root

    - name: Wait for SSH to be available
      wait_for:
        host: "{{ linode_instance.instance.ipv4[0] }}"
        port: 22
        delay: 30
        timeout: 300
```

**Play 2: Provision Instance (runs on remote host)**
```yaml
- name: Run initial configuration on new Linode
  hosts: new_linode
  vars:
    username: lavender
    new_hostname: fleur
    fqdn: fleur.lavnet.net
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Install basic packages
      apt:
        name: [vim, htop, curl, git]
        state: present

    - name: Create user lavender
      ansible.builtin.user:
        name: "{{ username }}"
        shell: /bin/bash
        groups: sudo
        state: present

    - name: Setup SSH keys
      ansible.builtin.copy:
        src: "~/.ssh/id_ed25519.pub"
        dest: "/home/{{ username }}/.ssh/authorized_keys"
        mode: "0600"

    - name: Set hostname
      ansible.builtin.command: >
        /usr/bin/hostnamectl --static set-hostname {{ fqdn }}

    - name: Update /etc/hosts
      ansible.builtin.lineinfile:
        path: /etc/hosts
        line: "{{ inventory_hostname }} {{ fqdn }} {{ new_hostname }}"

    # ISPConfig installation commented out but shows specialized provisioning
```

**What it does**: Creates Linode instance → waits for SSH → creates user → sets hostname → installs packages → prepares for ISPConfig

### Key Observations

**Both implementations are platform creation**:
- Proxmox: Template-based (build once, clone many)
- Linode: Direct instance creation
- Both require two phases: CREATE → PROVISION

**Distribution handling already exists**:
- `build-rocky9-cloud-init.sh` - Rocky 9.x
- `build-deb12-cloud-init.sh` - Debian 12
- User wants to add: Rocky 10.x

**This IS solti-platforms** - unifying these existing patterns into reusable Ansible roles.

---

## SOLTI Ecosystem Architecture

### Current Collections

| Collection | Status | Purpose |
|------------|--------|---------|
| **solti** | Documentation | Core documentation and architecture |
| **solti-monitoring** | Maturing | Monitoring stack (Telegraf, InfluxDB, Loki, Alloy) |
| **solti-containers** | Active | Testing containers (Mattermost, Redis, Elasticsearch) |
| **solti-ensemble** | Active | Shared services (MariaDB, Gitea, ISPConfig, security tools) |
| **solti-conductor** | Planned | Orchestration, inventory, multi-collection workflows |
| **solti-platforms** | **NEW** | VM/K3s platform creation and provisioning |

### SOLTI Acronym Philosophy

From parent documentation:
- **S**ystems: Managing system-of-systems
- **O**riented: Structured and purposeful
- **L**aboratory: Controlled testing environment
- **T**esting: Verification and validation
- **I**ntegration: Component interconnection

---

## Analysis: Expand vs. New Collection

### Option 1: Expand solti-containers

**Arguments FOR**:
- VMs could be "heavy containers"
- Reuse existing management scripts
- Keep everything together

**Arguments AGAINST**:
- ✅ **Philosophy conflict**: solti-containers explicitly chose "Lightweight Over Heavy: Containers instead of VMs"
- ✅ **Technology mismatch**: Podman/Quadlets vs. VM APIs/cloud-init
- ✅ **Lifecycle difference**: Containers (seconds, ephemeral) vs. VMs (minutes, longer-lived)
- ✅ **Use case mismatch**: Testing services vs. creating testing platforms
- ✅ **Architectural layers**: Services run IN environments vs. CREATING environments

### Option 2: Create solti-platforms

**Arguments FOR**:
- ✅ **Clear separation of concerns**: Platform creation vs. service deployment
- ✅ **Different technology stacks**: VM APIs, K3s, cloud-init vs. Podman, Quadlets
- ✅ **Natural dependency direction**: Platforms first, then services
- ✅ **Room to grow**: Bare metal, cloud instances, network management
- ✅ **Keeps philosophies pure**: Each collection maintains clear vision
- ✅ **User already has implementations**: Proxmox scripts + Linode playbook need a home

**Decision**: Create new collection - decisively confirmed by existing code.

---

## solti-ensemble Investigation

### What is solti-ensemble?

**Location**: `./solti-ensemble/`
**Purpose**: "Support tools and shared utilities" - Application-level services and security hardening
**Status**: Mature with 14 roles

### Three Categories of Roles

#### 1. Security & Auditing (5 roles)
- claude_sectest, fail2ban_config, sshd_harden, ispconfig_backup, ispconfig_cert_converge

#### 2. Infrastructure Services (3 roles)
- **mariadb**: Database server (traditional systemd service)
- **nfs-client**: Network storage client
- **ghost**: Blog platform (systemd service)

#### 3. Development Tools (6 roles)
- vs_code, gitea, podman, wireguard, etc.

### Key Findings

**Deployment Model**: Traditional Linux package installation + systemd services
- MariaDB via system package manager
- Gitea as systemd service
- NO Podman Quadlets
- NO container orchestration
- NO VM management

**Architectural Level**: APPLICATION LAYER
- Services installed ON existing hosts
- Security hardening OF hosts
- Dev tools FOR operators
- NOT platform creation

### Critical Insight: ensemble Does NOT Fill Platform Gap

**What ensemble provides**:
- Applications to install on hosts (MariaDB, Gitea, ISPConfig)
- Security configuration of hosts (fail2ban, SSH)
- Developer tools for operators (VS Code)

**What platforms provides**:
- The hosts themselves (VMs, K3s nodes)
- Platform provisioning (create/destroy)
- Host lifecycle management

**Different operational domains**:
- **ensemble**: "Configure this existing system"
- **platforms**: "Create the system to configure"

**Example workflow**:
```
platforms: Create Linode instance (fleur-create.yml play 1-2)
    ↓
ensemble: Install ISPConfig on that instance (fleur-create.yml commented section)
```

---

## The Revised Architecture Model

### User's Mental Model (Confirmed Correct)

**conductor**: "Inventory files and main specialized applications" - **orchestration layer**
**platforms**: "Proxmox management part of vm stuff" - **platform creation layer**

### Four-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 0: ORCHESTRATION & COORDINATION                           │
│ (The conductor of the orchestra)                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  solti-conductor                                                │
│  ├── Inventory management (hosts, groups, variables)           │
│  ├── Multi-collection workflows                                 │
│  ├── Test orchestration (platforms → apps → tests → report)    │
│  ├── Master playbooks that call other collections              │
│  └── "The sheet music that coordinates all performers"         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 1: PLATFORM CREATION & PROVISIONING                       │
│ (Creates the stages where applications perform)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  solti-platforms ◄─── NEW COLLECTION                            │
│  ├── Proxmox templates: build-rocky9/deb12 scripts as roles    │
│  ├── Proxmox VMs: Clone from templates, configure              │
│  ├── Linode instances: fleur-create.yml as role                │
│  ├── K3s clusters: Control plane + workers on Pi farm          │
│  ├── Platform provisioning: User setup, hostname, packages     │
│  └── "Creates and prepares the infrastructure"                 │
│                                                                  │
│  Target Distributions:                                          │
│  ├── Rocky Linux 9.x                                            │
│  ├── Rocky Linux 10.x                                           │
│  └── Debian 12                                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 2: APPLICATION SERVICES                                   │
│ (Applications that run on the platforms)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  solti-monitoring                                               │
│  ├── Monitoring stack: Telegraf, InfluxDB, Loki, Alloy         │
│  ├── Deploys TO platforms created by Layer 1                   │
│  └── Testing across Rocky 9.x, Rocky 10.x, Debian 12           │
│                                                                  │
│  solti-containers                                               │
│  ├── Testing containers: Mattermost, Redis, Elasticsearch      │
│  ├── Podman Quadlets + systemd                                 │
│  └── Runs ON platforms created by Layer 1                      │
│                                                                  │
│  solti-ensemble                                                 │
│  ├── Shared services: MariaDB, Gitea, ISPConfig                │
│  ├── Security tools: fail2ban, SSH hardening                   │
│  └── Deployed TO platforms created by Layer 1                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

**Layer 0: Orchestration (conductor)**
- Master inventory management
- Multi-collection playbook coordination
- Testing workflow automation (create platform → deploy apps → run tests → collect results)
- "The playbook that calls other collections in the right order"

**Layer 1: Platforms (platforms - NEW)**
- Creates compute platforms (VMs, K3s clusters)
- OS template management (Rocky 9.x/10.x, Debian 12)
- Base provisioning (users, SSH, hostname, packages)
- Platform lifecycle (create → configure → destroy)
- Implements user's existing Proxmox scripts and Linode playbooks

**Layer 2: Applications (monitoring/containers/ensemble)**
- Deploys services on platforms
- Application configuration
- Service management
- Testing and monitoring

---

## Technology Comparison

### Across Collections

| Aspect | solti-containers | solti-ensemble | solti-platforms (proposed) |
|--------|------------------|----------------|---------------------------|
| **Layer** | Application | Application | Platform |
| **Deployment** | Podman Quadlets | systemd services | VM APIs, K3s, cloud-init |
| **Management** | manage-svc.sh | Standard playbooks | manage-platform.sh |
| **Lifecycle** | Deploy/remove | Install/configure | Create/destroy |
| **Speed** | Seconds | Minutes | Minutes |
| **State** | Stateless | Stateful | Stateful |
| **Technology** | Podman, Quadlets | apt/dnf, systemd | Proxmox qm, Linode API, K3s |
| **Philosophy** | Fast iteration | Shared services | Platform creation |
| **Examples** | Redis, Elasticsearch | MariaDB, ISPConfig | User's Proxmox/Linode scripts |

### Technology Stack per Layer

**solti-platforms** (proposed):
- Proxmox `qm` commands (VM creation, template management)
- Linode API (`linode.cloud.instance` module)
- cloud-init (VM initialization)
- K3s binaries (cluster deployment)
- kubectl (cluster management)
- qemu-img (disk image manipulation)
- SSH/Ansible (provisioning)

**solti-containers**:
- Podman API
- Systemd/Quadlets
- Container registries
- Podman networks

**solti-ensemble**:
- APT/DNF package managers
- Systemd service files
- ISPConfig installer
- MariaDB, Gitea packages

---

## Platform Pattern: CREATE → PROVISION

Analysis of user's existing code reveals consistent two-phase pattern:

### Phase 1: CREATE
**Objective**: Bring platform into existence

**Proxmox**:
```bash
qm create $VMID --name "rocky9-template" --memory 4096 ...
qm importdisk $VMID image.qcow2 $STORAGE
qm template $VMID
```

**Linode**:
```yaml
linode.cloud.instance:
  label: fleur
  type: g6-standard-2
  image: linode/debian12
  state: present
```

**K3s** (planned):
```bash
curl -sfL https://get.k3s.io | sh -s - server
```

### Phase 2: PROVISION
**Objective**: Configure platform for use

**Common tasks across all platforms**:
1. Create operational user (lavender)
2. Setup SSH keys
3. Configure sudo access
4. Set hostname/FQDN
5. Update /etc/hosts
6. Install base packages (vim, git, curl, htop)
7. Update package cache
8. Platform-specific setup

**Why separate phases?**
- CREATE often runs on localhost (API calls)
- PROVISION runs on remote platform (SSH)
- CREATE can fail fast (API errors)
- PROVISION can be retried independently
- Matches user's existing Linode playbook structure

### Platform Base Role Pattern

Common provisioning tasks should be centralized:

```
solti-platforms/
└── roles/
    ├── platform_base/              # Common provisioning
    │   ├── tasks/
    │   │   ├── create_user.yml     # lavender user + sudo
    │   │   ├── setup_ssh.yml       # SSH keys
    │   │   ├── set_hostname.yml    # hostname + /etc/hosts
    │   │   └── install_base.yml    # vim, git, curl, htop
    │   └── defaults/
    │       └── main.yml            # Default user, packages
    │
    └── proxmox_template/           # Uses platform_base
        └── meta/
            └── main.yml            # Depends on platform_base
```

---

## Proposed solti-platforms Structure

### Directory Layout

```
solti-platforms/
├── roles/
│   ├── platform_base/                  # Common provisioning (reusable)
│   │   ├── tasks/
│   │   │   ├── main.yml                # Entry point
│   │   │   ├── create_user.yml         # From fleur-create.yml lines 106-133
│   │   │   ├── setup_ssh.yml           # SSH key deployment
│   │   │   ├── set_hostname.yml        # From fleur-create.yml lines 136-153
│   │   │   ├── update_hosts.yml        # /etc/hosts management
│   │   │   └── install_packages.yml    # From fleur-create.yml lines 94-101
│   │   ├── defaults/
│   │   │   └── main.yml                # platform_user: lavender, etc.
│   │   └── README.md
│   │
│   ├── proxmox_template/               # FIRST ROLE - Template builder
│   │   ├── tasks/
│   │   │   ├── main.yml                # Orchestrates template build
│   │   │   ├── download_image.yml      # wget cloud image
│   │   │   ├── resize_image.yml        # qemu-img resize
│   │   │   ├── create_vm.yml           # qm create with hardware config
│   │   │   ├── import_disk.yml         # qm importdisk
│   │   │   ├── configure_vm.yml        # qm set (boot, storage, etc.)
│   │   │   ├── setup_cloudinit.yml     # qm set (cloud-init settings)
│   │   │   ├── convert_template.yml    # qm template
│   │   │   └── verify.yml              # Template verification
│   │   ├── defaults/
│   │   │   └── main.yml                # VMID, storage, distro configs
│   │   ├── vars/
│   │   │   ├── rocky9.yml              # Rocky 9.x specific vars
│   │   │   ├── rocky10.yml             # Rocky 10.x specific vars
│   │   │   └── debian12.yml            # Debian 12 specific vars
│   │   ├── templates/
│   │   │   └── cloud-init.cfg.j2       # cloud-init template
│   │   └── README.md
│   │
│   ├── proxmox_vm/                     # VM lifecycle from template
│   │   ├── tasks/
│   │   │   ├── main.yml                # Entry point
│   │   │   ├── clone.yml               # qm clone from template
│   │   │   ├── configure.yml           # VM-specific config
│   │   │   ├── start.yml               # qm start
│   │   │   ├── stop.yml                # qm stop
│   │   │   ├── destroy.yml             # qm destroy
│   │   │   └── verify.yml              # VM health check
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   ├── linode_instance/                # Based on fleur-create.yml
│   │   ├── tasks/
│   │   │   ├── main.yml                # Entry point
│   │   │   ├── create.yml              # Lines 31-62 (API create)
│   │   │   ├── wait_ssh.yml            # Lines 56-62 (wait for ready)
│   │   │   ├── provision.yml           # Calls platform_base
│   │   │   ├── destroy.yml             # linode.cloud.instance state=absent
│   │   │   └── verify.yml              # Instance health
│   │   ├── defaults/
│   │   │   └── main.yml                # Type, region, image defaults
│   │   ├── meta/
│   │   │   └── main.yml                # Depends on platform_base
│   │   └── README.md
│   │
│   ├── k3s_control/                    # K3s control plane
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   ├── install.yml             # K3s installation
│   │   │   ├── bootstrap.yml           # Initialize cluster
│   │   │   ├── configure.yml           # Cluster config
│   │   │   └── verify.yml              # Cluster health
│   │   ├── templates/
│   │   │   ├── k3s-config.yml.j2
│   │   │   └── kubeconfig.j2
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   ├── k3s_worker/                     # K3s worker nodes
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   ├── install.yml             # K3s agent installation
│   │   │   ├── join.yml                # Join to control plane
│   │   │   ├── configure.yml           # Node config
│   │   │   └── verify.yml              # Node health
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   ├── ispconfig_server/               # ISPConfig on platform
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   ├── prepare_platform.yml    # Use platform_base
│   │   │   ├── download_installer.yml  # From fleur-create.yml lines 172-175
│   │   │   ├── run_installer.yml       # ISPConfig installer
│   │   │   ├── extract_credentials.yml # From lines 197-206
│   │   │   └── verify.yml              # ISPConfig health
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   └── README.md
│   │
│   └── wazuh_server/                   # Wazuh server provisioning
│       ├── tasks/
│       │   ├── main.yml
│       │   ├── download.yml            # Download Wazuh packages
│       │   ├── install.yml             # Install Wazuh
│       │   ├── configure.yml           # Configure agents
│       │   └── verify.yml              # Wazuh health check
│       ├── templates/
│       │   └── wazuh-config.yml.j2
│       ├── defaults/
│       │   └── main.yml
│       └── README.md
│
├── docs/                               # Documentation
│   ├── Platform-Pattern.md             # How to add new platforms
│   ├── Two-Phase-Model.md              # CREATE → PROVISION explained
│   ├── Distribution-Support.md         # Rocky 9.x/10.x, Debian 12
│   ├── Proxmox-Templates.md            # Template building guide
│   ├── Linode-Integration.md           # Linode API usage
│   ├── K3s-Cluster-Setup.md            # K3s deployment guide
│   ├── ISPConfig-Provisioning.md       # ISPConfig automation
│   └── Testing-Strategy.md             # Molecule for platforms
│
├── playbooks/                          # Example playbooks
│   ├── build-all-templates.yml         # Build Rocky 9/10 + Debian 12
│   ├── create-test-vm.yml              # Create VM for testing
│   ├── provision-ispconfig.yml         # Full ISPConfig setup
│   └── deploy-k3s-cluster.yml          # Full K3s deployment
│
├── inventory/                          # Example inventories
│   ├── proxmox.yml                     # Proxmox configuration
│   ├── linode.yml                      # Linode configuration
│   └── pi-farm.yml                     # Raspberry Pi cluster
│
├── tmp/                                # Generated playbooks (debug)
│
├── manage-platform.sh                  # Platform lifecycle script
├── platform-exec.sh                    # Task execution wrapper
├── ansible.cfg                         # Ansible settings
├── README.md                           # Project overview
├── CLAUDE.md                           # Claude Code context
└── galaxy.yml                          # Collection metadata
```

### Key Patterns from solti-containers

**Reuse These Patterns**:
1. ✅ Base role for common functionality (`_base` → `platform_base`)
2. ✅ Dynamic playbook generation (manage-platform.sh)
3. ✅ Task execution wrapper (platform-exec.sh)
4. ✅ Inventory-driven configuration
5. ✅ Per-role verification tasks
6. ✅ Documentation structure (docs/, per-role READMEs)
7. ✅ Distribution-specific vars files

**Adapt for Platforms**:
- Two-phase model (CREATE → PROVISION)
- Remote execution (SSH to platforms)
- Distribution handling (Rocky 9.x/10.x, Debian 12)
- API interactions (Proxmox, Linode)
- State tracking (which VMs exist)

---

## Use Case Examples

### Use Case 1: Build Proxmox Templates (FIRST IMPLEMENTATION)

**Goal**: Build templates for Rocky 9.x, Rocky 10.x, Debian 12

**Current workflow** (manual scripts):
```bash
cd build_templates_original
./build-rocky9-cloud-init.sh
./build-deb12-cloud-init.sh
# Manually track which templates exist
```

**Future workflow** (solti-platforms):
```bash
# Build all templates
./manage-platform.sh proxmox_template build --all

# Or build specific distribution
./manage-platform.sh proxmox_template build --os rocky9
./manage-platform.sh proxmox_template build --os rocky10
./manage-platform.sh proxmox_template build --os debian12

# Verify templates
./platform-exec.sh proxmox_template verify
```

**Playbook example**:
```yaml
# playbooks/build-all-templates.yml
- name: Build Proxmox templates for all distributions
  hosts: localhost
  vars:
    distributions:
      - rocky9
      - rocky10
      - debian12
  tasks:
    - name: Build templates
      include_role:
        name: proxmox_template
      vars:
        template_distribution: "{{ item }}"
      loop: "{{ distributions }}"
```

### Use Case 2: Test solti-monitoring on Fresh VMs

**Goal**: Test monitoring on Rocky 9.x, Rocky 10.x, Debian 12

```bash
# Create test VMs from templates
./manage-platform.sh proxmox_vm create --name test-rocky9 --template rocky9
./manage-platform.sh proxmox_vm create --name test-rocky10 --template rocky10
./manage-platform.sh proxmox_vm create --name test-debian12 --template debian12

# Provision with base setup
./platform-exec.sh proxmox_vm provision --all

# Deploy monitoring (different collection)
cd ../solti-monitoring
./manage-svc.sh telegraf deploy --target test-rocky9
./manage-svc.sh telegraf deploy --target test-rocky10
./manage-svc.sh telegraf deploy --target test-debian12

# Run tests...

# Cleanup
cd ../solti-platforms
./manage-platform.sh proxmox_vm destroy --all
```

### Use Case 3: ISPConfig on Linode

**Goal**: Deploy ISPConfig server on Linode (based on fleur-create.yml)

**Current workflow** (manual):
```bash
ansible-playbook build_templates_original/fleur-create.yml
# Manually uncomment ISPConfig section
```

**Future workflow** (solti-platforms):
```bash
# Create and provision Linode instance
./manage-platform.sh linode_instance create \
  --name ispconfig-prod \
  --type g6-standard-4 \
  --region us-central \
  --image debian12

# Deploy ISPConfig
./manage-platform.sh ispconfig_server install --host ispconfig-prod

# Verify
./platform-exec.sh ispconfig_server verify --host ispconfig-prod
```

### Use Case 4: K3s on Raspberry Pi Farm

**Goal**: Deploy K3s cluster on 4 Raspberry Pi nodes

```bash
# Bootstrap control plane
./manage-platform.sh k3s_control bootstrap --host rpi-control-01

# Join workers
./manage-platform.sh k3s_worker join --host rpi-worker-01
./manage-platform.sh k3s_worker join --host rpi-worker-02
./manage-platform.sh k3s_worker join --host rpi-worker-03

# Verify cluster
./platform-exec.sh k3s_control verify

# Get kubeconfig
./platform-exec.sh k3s_control kubeconfig > ~/.kube/config

# Deploy workloads
kubectl apply -f monitoring-stack.yml
```

### Use Case 5: Multi-Platform Testing Matrix

**Goal**: Test across 3 OS × 2 platforms (orchestrated by conductor)

```bash
# This would be a conductor playbook calling platforms
# conductor/playbooks/test-matrix.yml

- name: Create test matrix
  hosts: localhost
  tasks:
    # Proxmox VMs
    - name: Create Proxmox test VMs
      include_role:
        name: jackaltx.solti_platforms.proxmox_vm
      vars:
        vm_name: "test-{{ item }}-proxmox"
        template: "{{ item }}"
      loop: [rocky9, rocky10, debian12]

    # Linode instances
    - name: Create Linode test instances
      include_role:
        name: jackaltx.solti_platforms.linode_instance
      vars:
        instance_name: "test-{{ item }}-linode"
        image: "{{ item }}"
      loop: [rocky9, debian12]

- name: Deploy monitoring to all
  hosts: test_platforms
  tasks:
    - include_role:
        name: jackaltx.solti_monitoring.telegraf

- name: Run tests
  hosts: test_platforms
  tasks:
    - include_role:
        name: jackaltx.solti_monitoring.verify
```

---

## Integration Points

### With Other Collections

**solti-conductor** (Orchestration Layer):
```yaml
# conductor coordinates multi-collection workflows
- name: Full testing workflow
  hosts: localhost
  tasks:
    - name: Create platforms
      include_role:
        name: jackaltx.solti_platforms.proxmox_vm

    - name: Deploy monitoring
      include_role:
        name: jackaltx.solti_monitoring.telegraf

    - name: Deploy test containers
      include_role:
        name: jackaltx.solti_containers.redis

    - name: Run tests and collect results
      # ...
```

**solti-monitoring** (Application Layer):
```
platforms: Creates test VMs (Rocky 9/10, Debian 12)
    ↓
monitoring: Deploys Telegraf/InfluxDB to those VMs
```

**solti-containers** (Application Layer):
```
platforms: Creates VM or K3s cluster
    ↓
containers: Runs Redis/Elasticsearch in Podman on that platform
```

**solti-ensemble** (Application Layer):
```
platforms: Creates Linode instance (fleur-create.yml play 1-2)
    ↓
ensemble: Installs ISPConfig (fleur-create.yml commented section)
    or: Installs MariaDB for production database
```

### Dependency Flow

```
┌──────────────┐
│ conductor    │  Orchestrates workflows across collections
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ platforms    │  Creates VMs, K3s clusters (Rocky 9/10, Debian 12)
└──────┬───────┘
       │
       ├──────────────┬──────────────┬──────────────┐
       ▼              ▼              ▼              ▼
┌──────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────┐
│ monitoring   │ │ containers │ │ ensemble   │ │ custom   │
└──────────────┘ └────────────┘ └────────────┘ └──────────┘
  Applications run on platforms (deployed by conductor)
```

### Inventory Integration

**platforms inventory** (managed by platforms collection):
```yaml
# inventory/proxmox.yml
all:
  children:
    proxmox_templates:
      hosts:
        localhost:
      vars:
        proxmox_storage: local-lvm
        proxmox_bridge: vmbr0
        templates:
          rocky9:
            vmid: 7000
            image_url: "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
          rocky10:
            vmid: 7001
            image_url: "https://dl.rockylinux.org/pub/rocky/10/images/x86_64/Rocky-10-GenericCloud.latest.x86_64.qcow2"
          debian12:
            vmid: 9001
            image_url: "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"

    test_vms:
      hosts:
        test-rocky9:
          ansible_host: 192.168.1.100
          template: rocky9
        test-rocky10:
          ansible_host: 192.168.1.101
          template: rocky10
        test-debian12:
          ansible_host: 192.168.1.102
          template: debian12
```

**conductor inventory** (references platforms):
```yaml
# conductor/inventory.yml
all:
  children:
    monitoring_targets:
      hosts:
        test-rocky9:
          ansible_host: 192.168.1.100  # From platforms
        test-rocky10:
          ansible_host: 192.168.1.101  # From platforms
        test-debian12:
          ansible_host: 192.168.1.102  # From platforms
```

---

## First Role: proxmox_template

**Priority**: Build first, test with all three distributions

### Implementation Plan

Based on user's existing `build-rocky9-cloud-init.sh` and `build-deb12-cloud-init.sh`:

#### Role Structure
```
roles/proxmox_template/
├── tasks/
│   ├── main.yml                    # Orchestrates build process
│   ├── download_image.yml          # wget cloud image
│   ├── resize_image.yml            # qemu-img resize 8G
│   ├── create_vm.yml               # qm create with hardware
│   ├── import_disk.yml             # qm importdisk
│   ├── configure_storage.yml       # qm set (disk config)
│   ├── setup_cloudinit.yml         # qm set (cloud-init)
│   ├── convert_template.yml        # qm template
│   ├── cleanup.yml                 # Remove downloaded images
│   └── verify.yml                  # Verify template exists
├── defaults/
│   └── main.yml                    # Default variables
├── vars/
│   ├── rocky9.yml                  # Rocky 9.x config
│   ├── rocky10.yml                 # Rocky 10.x config
│   └── debian12.yml                # Debian 12 config
└── README.md
```

#### Distribution Variables

**vars/rocky9.yml**:
```yaml
---
template_vmid: 7000
template_name: rocky9-template
template_os_type: l26
template_image_url: "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
template_image_file: "Rocky-9-GenericCloud.latest.x86_64.qcow2"
template_tags: "rocky-template,rocky9,cloudinit"
```

**vars/rocky10.yml**:
```yaml
---
template_vmid: 7001
template_name: rocky10-template
template_os_type: l26
template_image_url: "https://dl.rockylinux.org/pub/rocky/10/images/x86_64/Rocky-10-GenericCloud.latest.x86_64.qcow2"
template_image_file: "Rocky-10-GenericCloud.latest.x86_64.qcow2"
template_tags: "rocky-template,rocky10,cloudinit"
```

**vars/debian12.yml**:
```yaml
---
template_vmid: 9001
template_name: debian12-template
template_os_type: l26
template_image_url: "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
template_image_file: "debian-12-generic-amd64.qcow2"
template_tags: "debian-template,debian-12,cloudinit"
```

#### Common Defaults

**defaults/main.yml**:
```yaml
---
# Distribution to build (rocky9, rocky10, debian12)
template_distribution: rocky9

# Proxmox configuration
proxmox_storage: local-lvm
proxmox_bridge: vmbr0

# VM hardware configuration
template_memory: 4096
template_balloon: 1
template_cores: 4
template_cpu_type: host
template_numa: 1
template_bios: ovmf
template_machine: q35

# Disk configuration
template_disk_size: 8G
template_disk_controller: virtio-scsi-pci
template_disk_options: discard=on

# Network configuration
template_network_model: virtio
template_network_mtu: 1

# cloud-init configuration
template_ci_user: "{{ ansible_user_id }}"
template_ci_sshkeys: "{{ ansible_user_dir }}/.ssh/authorized_keys"
template_ci_ipconfig: "ip=dhcp"

# Agent
template_qemu_agent: 1

# Working directory for downloads
template_work_dir: "/tmp/proxmox-templates"
```

#### Key Tasks

**tasks/main.yml**:
```yaml
---
- name: Include distribution-specific variables
  include_vars: "{{ template_distribution }}.yml"

- name: Create work directory
  file:
    path: "{{ template_work_dir }}"
    state: directory
    mode: '0755'

- name: Download cloud image
  include_tasks: download_image.yml

- name: Resize disk image
  include_tasks: resize_image.yml

- name: Destroy existing VM if exists
  command: "qm destroy {{ template_vmid }}"
  ignore_errors: true
  become: true

- name: Create VM
  include_tasks: create_vm.yml

- name: Import disk
  include_tasks: import_disk.yml

- name: Configure storage
  include_tasks: configure_storage.yml

- name: Setup cloud-init
  include_tasks: setup_cloudinit.yml

- name: Convert to template
  include_tasks: convert_template.yml

- name: Cleanup downloaded images
  include_tasks: cleanup.yml
  when: template_cleanup | default(true)

- name: Verify template
  include_tasks: verify.yml
```

**tasks/create_vm.yml** (from user's script):
```yaml
---
- name: Create Proxmox VM
  command: >
    qm create {{ template_vmid }}
    --name {{ template_name }}
    --ostype {{ template_os_type }}
    --memory {{ template_memory }}
    --balloon {{ template_balloon }}
    --agent {{ template_qemu_agent }}
    --bios {{ template_bios }}
    --machine {{ template_machine }}
    --efidisk0 {{ proxmox_storage }}:0,pre-enrolled-keys=0
    --cpu {{ template_cpu_type }}
    --cores {{ template_cores }}
    --numa {{ template_numa }}
    --vga serial0
    --serial0 socket
    --net0 {{ template_network_model }},bridge={{ proxmox_bridge }},mtu={{ template_network_mtu }}
  become: true
  register: vm_create

- name: Display VM creation result
  debug:
    var: vm_create.stdout_lines
```

### Testing Strategy

**Manual testing first**:
```bash
# Test Rocky 9
ansible-playbook -i inventory/proxmox.yml playbooks/build-all-templates.yml \
  -e template_distribution=rocky9

# Test Rocky 10
ansible-playbook -i inventory/proxmox.yml playbooks/build-all-templates.yml \
  -e template_distribution=rocky10

# Test Debian 12
ansible-playbook -i inventory/proxmox.yml playbooks/build-all-templates.yml \
  -e template_distribution=debian12

# Verify all templates exist
qm list | grep -E '(rocky9|rocky10|debian12)-template'
```

**Future: Molecule testing** (after role stabilizes)

---

## Next Steps

### Phase 1: Foundation (Week 1-2)

**PRIORITY 1: proxmox_template role**

1. **Initialize Collection**
   ```bash
   cd /home/lavender/sandbox/ansible/jackaltx
   ansible-galaxy collection init jackaltx.solti_platforms
   cd jackaltx/solti_platforms
   ```

2. **Create Base Structure**
   ```bash
   mkdir -p roles/{platform_base,proxmox_template}
   mkdir -p docs playbooks inventory tmp
   ```

3. **Implement proxmox_template Role**
   - Convert `build-rocky9-cloud-init.sh` to Ansible tasks
   - Convert `build-deb12-cloud-init.sh` to Ansible tasks
   - Add Rocky 10.x support
   - Create distribution-specific vars files
   - Implement verification tasks

4. **Test Template Building**
   - Build Rocky 9.x template
   - Build Rocky 10.x template
   - Build Debian 12 template
   - Verify all three templates work

5. **Documentation**
   - `README.md` - Project overview
   - `CLAUDE.md` - Claude Code context
   - `roles/proxmox_template/README.md` - Role documentation
   - `docs/Proxmox-Templates.md` - Template building guide

### Phase 2: Platform Base (Week 3)

6. **platform_base Role**
   - Extract common provisioning from fleur-create.yml
   - Create user management tasks
   - Hostname configuration tasks
   - Package installation tasks
   - Reusable across all platform types

### Phase 3: Proxmox VMs (Week 4)

7. **proxmox_vm Role**
   - Clone from template
   - VM configuration
   - Start/stop/destroy
   - Integration with platform_base

### Phase 4: Linode (Week 5)

8. **linode_instance Role**
   - Convert fleur-create.yml to role
   - API integration
   - Use platform_base for provisioning

### Phase 5: Management Scripts (Week 6)

9. **Utility Scripts**
   - `manage-platform.sh` - Adapted from solti-containers
   - `platform-exec.sh` - Task execution wrapper

### Phase 6: K3s (Week 7-8)

10. **K3s Roles**
    - k3s_control role
    - k3s_worker role
    - Cluster deployment to Pi farm

### Phase 7: Specialized Provisioning (Week 9+)

11. **ispconfig_server Role**
    - ISPConfig automation (from fleur-create.yml comments)

12. **wazuh_server Role**
    - Wazuh deployment

### Future Enhancements

- Bare metal provisioning (PXE boot)
- Additional cloud providers (AWS, DigitalOcean)
- Network management (VLANs, bridges)
- Template versioning and updates
- Automated backup/restore
- Cost tracking for cloud resources

---

## Questions to Answer During Development

### Technical Decisions

1. **Proxmox API**: Direct `qm` commands or Ansible Proxmox modules?
   - Current scripts use `qm` - stick with what works
   - Consider modules for proxmox_vm role

2. **Image Caching**: Cache downloaded images to avoid re-downloading?
   - Yes - keep in template_work_dir
   - Add cleanup option

3. **Template Updates**: How to update existing templates?
   - Destroy and rebuild approach initially
   - Version tracking later

4. **Distribution Detection**: How to detect which distro is needed?
   - Explicit parameter (template_distribution)
   - Inventory-driven

5. **State Tracking**: How to track which templates exist?
   - `qm list` queries
   - Inventory records

### Workflow Questions

1. **Concurrent Builds**: Can we build multiple templates in parallel?
   - Yes - different VMIDs
   - Need locking for shared resources

2. **Failed Builds**: How to handle partial failures?
   - Keep work directory for debugging
   - Clear rollback strategy

3. **Secrets Management**: How to handle Proxmox/Linode API tokens?
   - Ansible Vault (shown in fleur-create.yml)
   - Environment variables option

### Integration Questions

1. **Collection Dependencies**: Should platforms depend on ensemble?
   - No - platforms is lower layer
   - ensemble may depend on platforms

2. **Inventory Sharing**: One inventory or per-collection?
   - Per-collection with references
   - conductor has master inventory

---

## Success Criteria

### Minimum Viable Product (MVP)

**proxmox_template role complete**:
- ✅ Can build Rocky 9.x template from user's script
- ✅ Can build Rocky 10.x template
- ✅ Can build Debian 12 template from user's script
- ✅ Templates are functional and clonable
- ✅ Distribution-specific vars working
- ✅ Idempotent (can re-run without errors)

### Phase 1 Complete

- ✅ All three templates build successfully
- ✅ Templates verified on Proxmox
- ✅ Can clone VM from each template
- ✅ Documentation complete
- ✅ Ready for proxmox_vm role development

### Full Feature Set (Long-term)

- ✅ Complete Proxmox support (templates + VMs)
- ✅ Linode instance creation (fleur-create.yml as role)
- ✅ K3s cluster deployment on Pi farm
- ✅ ISPConfig server provisioning
- ✅ Integration with all SOLTI collections
- ✅ Comprehensive documentation
- ✅ Molecule testing

---

## References

### Internal Documentation
- `.claude/project-contexts/solti-containers-context.md` - Pattern reference
- `../solti-containers/CLAUDE.md` - Container patterns
- `../solti-containers/Container-Role-Architecture.md` - Three pillars
- `../solti-ensemble/` - Application service patterns
- `../CLAUDE.md` - Parent project context
- `build_templates_original/build-rocky9-cloud-init.sh` - Proxmox reference
- `build_templates_original/build-deb12-cloud-init.sh` - Proxmox reference
- `build_templates_original/fleur-create.yml` - Linode reference

### External Resources
- [Proxmox API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
- [Proxmox qm Command](https://pve.proxmox.com/pve-docs/qm.1.html)
- [K3s Documentation](https://docs.k3s.io/)
- [cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Linode API Documentation](https://www.linode.com/docs/api/)
- [Ansible Proxmox Modules](https://docs.ansible.com/ansible/latest/collections/community/general/proxmox_module.html)
- [Ansible Linode Collection](https://galaxy.ansible.com/ui/repo/published/linode/cloud/)

### Distribution Resources
- [Rocky Linux Cloud Images](https://dl.rockylinux.org/pub/rocky/)
- [Debian Cloud Images](https://cloud.debian.org/images/cloud/)

---

## Changelog

**2025-11-10** (Evening):
- **IMPLEMENTATION COMPLETE**: Phase 1 finished
  - Collection initialized: `solti-platforms` (hyphen, not underscore)
  - proxmox_template role fully implemented (10 task files)
  - All three distributions configured (Rocky 9.x, Rocky 10.x, Debian 12)
  - Playbooks created (build-all, build-single)
  - Inventory and ansible.cfg configured
  - Complete documentation (Collection README, CLAUDE.md, Role README)
  - Syntax validated, ready for testing
  - Added to .gitignore for separate repo

**Implementation Notes**:
- Naming: Use hyphen (solti-platforms) not underscore (Ansible interprets _ as variable)
- Structure: Collection must be at correct level, not nested in extra directory
- Roles: Must be inside collection, not at parent level
- Pattern validated: Distribution-specific vars files work perfectly
- Ready for: GitHub repo creation, then testing on Proxmox

**2025-11-10** (Afternoon):
- Initial decision document created
- Architectural analysis completed
- solti-ensemble investigation confirmed no overlap
- **MAJOR UPDATE**: Added real implementation examples
  - User's Proxmox template build scripts analyzed
  - User's Linode provisioning playbook analyzed
  - Revised conductor definition (orchestration not Proxmox management)
  - Identified two-phase pattern (CREATE → PROVISION)
  - Specified first role: proxmox_template
  - Defined three target distributions: Rocky 9.x, Rocky 10.x, Debian 12
  - Updated architecture to four layers (0=conductor, 1=platforms, 2=apps)
- Ready for implementation with concrete examples

---

## Notes

### Why This Document Exists

This decision document serves multiple purposes:

1. **Decision Record**: Captures why we chose to create a new collection
2. **Architecture Reference**: Documents the four-layer SOLTI ecosystem
3. **Implementation Guide**: Provides structure and next steps based on real code
4. **Context for AI**: Comprehensive background for Claude Code sessions
5. **Team Onboarding**: Explains the reasoning for new contributors

### How to Use This Document

**For Implementation**:
- Reference "First Role: proxmox_template" for immediate work
- Use user's existing scripts as reference implementation
- Follow "Next Steps" for phased development
- Check "Platform Pattern" for CREATE → PROVISION model

**For Architecture Decisions**:
- Reference "Revised Architecture Model" for positioning
- Check "Integration Points" for inter-collection dependencies
- Review "Technology Comparison" for stack alignment

**For Claude Code Sessions**:
- Load this document for context on platforms work
- Reference solti-containers-context.md for patterns
- Use real implementation examples as templates

### Living Document

This document should evolve as solti-platforms develops:
- Update structure as roles are added
- Add discovered integration points
- Document architectural decisions
- Track success metrics

**When updating**: Add dated entries to Changelog section.

### Key Insight from User's Code

The user's existing implementations (Proxmox scripts + Linode playbook) perfectly demonstrate what solti-platforms should be. These aren't theoretical requirements - they're working code that needs a proper home. The collection will:

1. **Unify existing patterns**: Proxmox scripts + Linode playbook → consistent roles
2. **Add distribution support**: Rocky 9.x + Rocky 10.x + Debian 12
3. **Enable reuse**: Platform creation becomes reproducible and testable
4. **Support growth**: ISPConfig, Wazuh, K3s, and future platforms

**This is infrastructure-as-code for platform creation.**

---

**End of Document**
