# State Management Pattern

**Status**: Mandatory for all SOLTI roles
**Reference**: `solti-containers/roles/influxdb3/tasks/main.yml`

## Overview

All SOLTI roles use **state-based task organization** where the main.yml file is divided into clearly-marked blocks, each handling a specific state.

## The Pattern

### States

Roles must support one or more of these states:

| State | Purpose | When to Use |
|-------|---------|-------------|
| `prepare` | One-time system setup | Directories, SELinux, sysctl, user creation |
| `present` | Deploy/configure service | Normal deployment |
| `absent` | Remove service | Cleanup, testing |

### Visual Structure

```yaml
---
#
# role_name role - supports prepare, present, and absent states
# States:
#   prepare: One-time setup description
#   present: Deploy description
#   absent: Remove description
#

- name: Validate state parameter
  ansible.builtin.fail:
    msg: "role_state must be one of: prepare, present, absent. Current value: {{ role_state }}"
  when: role_state not in ['prepare', 'present', 'absent']

# =======================================================================
# PREPARATION (one-time setup)
# =======================================================================

- name: Prepare Role Name (one-time setup)
  when: role_state == 'prepare'
  block:
    - name: Check if already prepared
      # Idempotency check

    # All prepare tasks here

# =======================================================================
# DEPLOYMENT
# =======================================================================

- name: Install Role Name
  when: role_state == 'present'
  block:
    - name: Verify required directories exist
      # Ensure prepare was run

    # All present tasks here

# =======================================================================
# CLEANUP
# =======================================================================

- name: Remove Role Name
  when: role_state == 'absent'
  block:
    # All absent tasks here
```

## Visual Markers

### Section Separators

Use exactly this format for visual separation:

```yaml
# =======================================================================
# SECTION NAME
# =======================================================================
```

**Why**: Easy to scan with eyes. Stands out from task names.

### Block Names

Use descriptive block names that match the state:

```yaml
- name: Prepare Service Name (one-time setup)
  when: service_state == 'prepare'

- name: Install Service Name
  when: service_state == 'present'

- name: Remove Service Name
  when: service_state == 'absent'
```

## State Selection

### Three States (prepare/present/absent)

Use when service requires:
- System-level changes (sysctl, SELinux)
- Directory structure that persists across deploys
- User/group creation
- Network setup

**Example**: influxdb3, redis, elasticsearch

### Two States (present/absent)

Use when service:
- Has no system-level preparation
- Can be deployed/removed cleanly
- Doesn't need persistent directories

**Example**: proxmox_template (templates are ephemeral)

## State Validation

**Always validate** the state parameter at the start:

```yaml
- name: Validate state parameter
  ansible.builtin.fail:
    msg: "service_state must be one of: prepare, present, absent. Current value: {{ service_state }}"
  when: service_state not in ['prepare', 'present', 'absent']
```

**Why**: Fail fast with clear error message instead of undefined behavior.

## Idempotency Checks

### Prepare State

Check if preparation already done to avoid errors:

```yaml
- name: Prepare Service
  when: service_state == 'prepare'
  block:
    - name: Check if already prepared
      ansible.builtin.stat:
        path: "{{ service_data_dir }}"
      register: data_dir_check

    - name: Fail if already prepared
      ansible.builtin.fail:
        msg: "Service appears to be already prepared. Directory {{ service_data_dir }} exists."
      when: data_dir_check.stat.exists
```

### Present State

Verify prepare was run:

```yaml
- name: Install Service
  when: service_state == 'present'
  block:
    - name: Verify required directories exist
      ansible.builtin.stat:
        path: "{{ service_data_dir }}"
      register: config_dir_check
      failed_when: not config_dir_check.stat.exists
      changed_when: false
```

## Common Mistakes

### ❌ DON'T: Linear task flow

```yaml
# BAD - No state management
- name: Create directories
  file: ...

- name: Deploy container
  include_tasks: deploy.yml

- name: Configure service
  template: ...
```

**Problem**: Can't see state flow. Can't control what happens.

### ❌ DON'T: Hidden state in tags

```yaml
# BAD - State hidden in tags
- import_tasks: prepare.yml
  tags: [prepare]

- import_tasks: deploy.yml
  tags: [deploy]
```

**Problem**: Can't see the logic. Tags are for filtering, not flow control.

### ❌ DON'T: Ambiguous names

```yaml
# BAD - Unclear what this does
- name: Do stuff
  when: service_state == 'present'
```

**Problem**: "Do stuff" doesn't communicate intent.

### ✅ DO: Clear state blocks

```yaml
# GOOD - Clear state-based structure
# =======================================================================
# DEPLOYMENT
# =======================================================================

- name: Install InfluxDB3
  when: influxdb3_state == 'present'
  block:
    - name: Verify required directories exist
      # Clear, specific tasks
```

## Full Example

See [examples/influxdb3-annotated.yml](examples/influxdb3-annotated.yml) for a complete, annotated example.

## Defaults

Always include state in defaults/main.yml:

```yaml
---
# Role state (prepare, present, absent)
service_state: present
```

## Testing

Test each state independently:

```bash
# Prepare
ansible-playbook playbook.yml -e service_state=prepare -K

# Deploy
ansible-playbook playbook.yml -e service_state=present

# Remove
ansible-playbook playbook.yml -e service_state=absent -K
```

## Benefits

1. **Visual Clarity**: Scan with eyes, see the flow
2. **State Control**: Explicit control over what runs
3. **Error Handling**: Clear boundaries for error states
4. **Testing**: Each state testable independently
5. **Debugging**: Know exactly which state block failed
6. **Documentation**: Self-documenting structure

## Questions

- **Q**: Can I have more than 3 states?
- **A**: Rarely needed. Consider if you really need custom states or if present/absent with variables is clearer.

- **Q**: What about configure/initialize tasks?
- **A**: Those are sub-tasks within present state. Use include_tasks.

- **Q**: When should I use just present/absent?
- **A**: When there's no system-level preparation needed.

## See Also

- [role-structure.md](role-structure.md) - Directory layout
- [examples/influxdb3-annotated.yml](examples/influxdb3-annotated.yml) - Full example
