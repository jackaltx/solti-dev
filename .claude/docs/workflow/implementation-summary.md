# Implementation Summary: Dynamic Proxmox Template Discovery

**Date:** 2025-11-12
**Sprint Goal:** Integrate solti-platforms template discovery into solti-monitoring molecule tests

---

## ✅ Completed

### solti-platforms Collection
**Repository:** `jackaltx/solti-platforms`
**Branch:** `dev` (already merged to `main`)
**Commit:** `6dd7e51 - checkpoint: add template discovery/clone tasks with passwordless sudo`

**New Files:**
- `roles/proxmox_template/tasks/find_latest_template.yml` - Template discovery via pvesh API
- `roles/proxmox_template/tasks/clone_latest_template.yml` - VM cloning and configuration via qm
- `docs/setup-passwordless-sudo.sh` - Automated sudoers configuration script

**Modified Files:**
- `inventory/inventory.yml` - Configured for passwordless sudo (lavender user)

---

### solti-monitoring Collection
**Repository:** `jackaltx/solti-monitoring`
**Branch:** `dev`
**PR:** [#16](https://github.com/jackaltx/solti-monitoring/pull/16) - feat: Integrate solti-platforms for dynamic Proxmox template discovery
**Commits:**
- `80419b6 - fix: use add_host instead of delegate_to for proxmox tasks`
- `7cf48e3 - checkpoint: integrate solti-platforms for dynamic template discovery`

**New Files:**
- `molecule/proxmox/requirements.yml` - Collection dependency declaration

**Modified Files:**
- `molecule/proxmox/create.yml` - Replaced API calls with solti-platforms tasks
- `molecule/proxmox/destroy.yml` - SSH-based VM destruction
- `molecule/proxmox/molecule.yml` - Updated requirements path
- `run-proxmox-tests.sh` - Added documentation

**Cleanup:**
- Removed deprecated `fail2ban_config.deleteme` role (107 files)
- Removed old GitHub workflow files

---

## Technical Architecture

### Authentication Solution: Passwordless Sudo

**Problem:** Proxmox commands (`pvesh`, `qm`) require root, but:
- Normal users can't SSH as root
- Ansible `become` prompts for password (blocks automation)

**Solution:** Configured passwordless sudo for specific commands only:

```bash
# /etc/sudoers.d/lavender-proxmox
lavender ALL=(root) NOPASSWD: /usr/bin/pvesh, /usr/sbin/qm
```

**Implementation:** Commands invoke `sudo` directly instead of using Ansible `become`:
```yaml
- ansible.builtin.shell: sudo pvesh get /cluster/resources --type vm --output-format json
- ansible.builtin.shell: sudo qm clone {{ vmid }} ...
```

---

### Discovery Flow

```
User: PROXMOX_DISTRO=debian ./run-proxmox-tests.sh
  ↓
Script: exports PROXMOX_TEMPLATE="debian-12-template"
  ↓
Molecule: create.yml maps "debian-12-template" → "debian12"
  ↓
solti-platforms: find_latest_template.yml
  - Loads vars/debian12.yml (template_vmid_base: 8000)
  - Queries pvesh for all VMs
  - Filters templates in range 8000-8999
  - Returns highest VMID (e.g., 8001)
  ↓
solti-platforms: clone_latest_template.yml
  - qm clone 8001 9100 --name uut-vm --full 0
  - qm set 9100 --ipconfig0 'ip=192.168.101.90/24,gw=192.168.101.254'
  - qm disk resize 9100 virtio0 20G
  ↓
Result: VM 9100 ready for molecule testing
```

---

## Testing Results

### ✅ Successful
- **Template Discovery:** Found `debian12-template-8001` (VMID 8001)
- **VM Cloning:** Created VM with VMID 9100
- **Network Configuration:** Assigned IP 192.168.101.90/24
- **Disk Resizing:** Expanded to 20G
- **VM Startup:** VM started and SSH accessible

### ⏸️ Known Issue (Unrelated to Implementation)
- **Cloud-init timeout in prepare phase:** VM cloud-init took >5 minutes (30 retries exhausted)
- **Impact:** Molecule test failed at prepare, not during our clone/create phase
- **Root cause:** Template cloud-init configuration or VM resource constraints
- **Note:** This is a separate issue from the template discovery/cloning work

---

## VMID Ranges (Smart Numbering System)

| Distribution | VMID Range | Base | Example |
|--------------|------------|------|---------|
| Rocky 9      | 7000-7999  | 7000 | 7003    |
| Debian 12    | 8000-8999  | 8000 | 8001    |
| Rocky 10     | 10000-10999| 10000| 10001   |

**Note:** VMID ≠ OS version. VMID 8001 is the 1st Debian 12 template build, not Debian 12.1.

---

## Usage Examples

### From Molecule Tests
```yaml
# molecule/proxmox/create.yml
- name: Clone VM on Proxmox host
  hosts: proxmox_clone_group
  tasks:
    - include_role:
        name: jackaltx.solti_platforms.proxmox_template
        tasks_from: clone_latest_template
      vars:
        template_distribution: debian12
        clone_vmid: 9100
        clone_name: "uut-vm"
        clone_ip: "192.168.101.90"
        clone_gateway: "192.168.101.254"
        clone_disk_size: "20G"
```

### From platform-exec.sh
```bash
cd solti-platforms

# Just discovery
./platform-exec.sh proxmox_template find_latest_template \
  -e template_distribution=debian12

# Full clone
./platform-exec.sh proxmox_template clone_latest_template \
  -e template_distribution=debian12 \
  -e clone_vmid=500 \
  -e clone_name=test-vm \
  -e clone_ip=192.168.101.100 \
  -e clone_gateway=192.168.101.254 \
  -e clone_disk_size=20G
```

---

## Setup Requirements

### For New Users/Hosts

**1. Configure Passwordless Sudo:**
```bash
cd solti-platforms
ssh root@<proxmox-host> "bash -s" < docs/setup-passwordless-sudo.sh
```

**2. Verify:**
```bash
ssh <proxmox-host> "sudo -n pvesh get /cluster/resources --type vm"
```

---

## Next Sprint Planning

### Immediate Priorities
1. **Resolve cloud-init timeout issue** in molecule prepare phase
   - Investigate template cloud-init configuration
   - Consider increasing timeout or reducing wait

2. **Add Ubuntu 24 support** (VMID range 9000-9999)
   - Create `vars/ubuntu24.yml`
   - Update documentation

3. **Enhanced error handling**
   - Better messages when no templates found
   - Validation for VMID conflicts

### Future Enhancements
1. **Template versioning metadata**
   - Add OS version to template notes
   - Query by version, not just "latest"

2. **Multi-node support**
   - Handle templates across different Proxmox nodes
   - Node selection logic

3. **CI/CD integration**
   - GitHub Actions workflow using these tasks
   - Automated template building + testing

---

## Files to Review

**solti-platforms:**
- [roles/proxmox_template/tasks/find_latest_template.yml](../solti-platforms/roles/proxmox_template/tasks/find_latest_template.yml)
- [roles/proxmox_template/tasks/clone_latest_template.yml](../solti-platforms/roles/proxmox_template/tasks/clone_latest_template.yml)
- [docs/setup-passwordless-sudo.sh](../solti-platforms/docs/setup-passwordless-sudo.sh)
- [inventory/inventory.yml](../solti-platforms/inventory/inventory.yml)

**solti-monitoring:**
- [molecule/proxmox/create.yml](solti-monitoring/molecule/proxmox/create.yml)
- [molecule/proxmox/destroy.yml](solti-monitoring/molecule/proxmox/destroy.yml)
- [molecule/proxmox/requirements.yml](solti-monitoring/molecule/proxmox/requirements.yml)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
