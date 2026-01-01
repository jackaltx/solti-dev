# Documentation Audit Report
**Date**: 2025-12-31
**Scope**: solti-monitoring collection and mylab orchestrator

## Executive Summary

Comprehensive audit of documentation across the solti-monitoring Ansible Galaxy collection and mylab orchestrator. Identified gaps between actual implementation and documented features.

## Key Findings

### 1. mylab ↔ solti-monitoring Relationship Not Documented

**Current State:**
- mylab is the orchestrator containing site-specific deployment code
- solti-monitoring is the Ansible Galaxy collection (roles library)
- mylab imports and uses roles from `jackaltx.solti_monitoring.*`
- This relationship is implicit but not explicitly documented

**Evidence:**
- [mylab/playbooks/fleur/91-fleur-alloy-test.yml](mylab/playbooks/fleur/91-fleur-alloy-test.yml):55 uses `jackaltx.solti_monitoring.alloy`
- manage-svc.sh and svc-exec.sh live in mylab but are documented in collection role READMEs

**Impact:** Users of the galaxy collection won't understand how to use the orchestrator pattern

---

### 2. Test Mode Not Documented in Alloy Role

**Current State:**
- `alloy_test_mode` variable exists in [solti-monitoring/roles/alloy/defaults/main.yml](solti-monitoring/roles/alloy/defaults/main.yml):12-13
- Used in [solti-monitoring/roles/alloy/tasks/main.yml](solti-monitoring/roles/alloy/tasks/main.yml):33 to write config to /tmp
- Prevents service restart when testing configurations
- **NOT mentioned in README**

**Test Workflow:**
- [mylab/playbooks/fleur/91-fleur-alloy-test.yml](mylab/playbooks/fleur/91-fleur-alloy-test.yml) demonstrates complete test pattern:
  - Sets `alloy_test_mode: true`
  - Generates config in /tmp
  - Runs `alloy validate` on test config
  - Compares test config vs production config with `diff`
  - Displays next steps for deployment

**Impact:** Users don't know test mode exists or how to safely validate configs before deployment

---

### 3. Extra Task Files Not Documented in Role READMEs

**Roles with verify.yml Task Files:**
- [solti-monitoring/roles/alloy/tasks/verify.yml](solti-monitoring/roles/alloy/tasks/verify.yml)
- [solti-monitoring/roles/loki/tasks/verify.yml](solti-monitoring/roles/loki/tasks/verify.yml)
- [solti-monitoring/roles/loki/tasks/verify1.yml](solti-monitoring/roles/loki/tasks/verify1.yml)
- [solti-monitoring/roles/influxdb/tasks/verify.yml](solti-monitoring/roles/influxdb/tasks/verify.yml)
- [solti-monitoring/roles/wazuh_agent/tasks/verify.yml](solti-monitoring/roles/wazuh_agent/tasks/verify.yml)

**Other Extra Task Files:**
- alloy: [generate-sample-config.yml](solti-monitoring/roles/alloy/tasks/generate-sample-config.yml)
- influxdb: [influxdb-setup-systemd.yml](solti-monitoring/roles/influxdb/tasks/influxdb-setup-systemd.yml), [initializedb.yml](solti-monitoring/roles/influxdb/tasks/initializedb.yml)
- telegraf: [influxdb-localhost-operators-token.yml](solti-monitoring/roles/telegraf/tasks/influxdb-localhost-operators-token.yml), [telegrafd-default-setup.yml](solti-monitoring/roles/telegraf/tasks/telegrafd-default-setup.yml), [telegrafd-inputs-setup.yml](solti-monitoring/roles/telegraf/tasks/telegrafd-inputs-setup.yml), [telegrafd-outputs-setup.yml](solti-monitoring/roles/telegraf/tasks/telegrafd-outputs-setup.yml)
- wazuh_agent: [configure.yml](solti-monitoring/roles/wazuh_agent/tasks/configure.yml), [detect_services.yml](solti-monitoring/roles/wazuh_agent/tasks/detect_services.yml), [install.yml](solti-monitoring/roles/wazuh_agent/tasks/install.yml), [remove.yml](solti-monitoring/roles/wazuh_agent/tasks/remove.yml), [verify-config.yml](solti-monitoring/roles/wazuh_agent/tasks/verify-config.yml)

**How They're Used:**
- Called via `svc-exec.sh` script with entry point parameter
- Example: `./svc-exec alloy verify` runs verify.yml
- Example: `./svc-exec loki verify1` runs verify1.yml
- Referenced in role READMEs but not shown in directory structure

**Impact:** Users don't know these task files exist or how to invoke them

---

### 4. Directory Structure Incomplete in READMEs

**Alloy Role README Shows:**
```
alloy/
├── tasks/
│   ├── main.yml
│   └── verify.yml            # ✓ Shown
```

**But Missing:**
```
alloy/
├── tasks/
│   ├── generate-sample-config.yml   # ✗ Not shown
│   ├── main.yml
│   └── verify.yml
```

**Impact:** Incomplete picture of role capabilities

---

### 5. Test Playbook Patterns Not Referenced

**mylab Test Playbooks Found:**
- [mylab/playbooks/fleur/91-fleur-alloy-test.yml](mylab/playbooks/fleur/91-fleur-alloy-test.yml) - Alloy config validation workflow
- [mylab/playbooks/test-monitor-all-logs.yml](mylab/playbooks/test-monitor-all-logs.yml) - Integration testing

**Status:** These demonstrate best practices but aren't referenced in collection documentation

**Impact:** Users miss valuable testing patterns

---

## Documentation Gaps by Role

### Alloy Role
**README Status:** Comprehensive (476 lines)
**Missing:**
- `alloy_test_mode` variable and workflow
- Test playbook reference (91-fleur-alloy-test.yml)
- `generate-sample-config.yml` task file
- `verify.yml` task file details

### Loki Role
**README Status:** Good
**Missing:**
- `verify.yml` and `verify1.yml` task files
- How to invoke with svc-exec.sh

### InfluxDB Role
**README Status:** Unknown (not reviewed in detail)
**Missing:**
- Extra task files (influxdb-setup-systemd.yml, initializedb.yml, verify.yml)

### Telegraf Role
**README Status:** Unknown (not reviewed in detail)
**Missing:**
- Multiple setup task files not documented

### Wazuh Agent Role
**README Status:** Unknown (not reviewed in detail)
**Missing:**
- All extra task files (configure, install, remove, verify, detect_services, verify-config)

---

## Recommended Actions

### Priority 1: Critical Gaps
1. **Document test mode in Alloy README**
   - Add `alloy_test_mode` to Role Variables section
   - Add "Testing Configuration Changes" section showing 91-fleur-alloy-test.yml pattern
   - Update directory structure to show all task files

2. **Document verify.yml pattern across all roles**
   - Add "Verification Tasks" section to each role README
   - Show how to invoke with svc-exec.sh
   - Explain what each verify task checks

### Priority 2: Architecture Documentation
3. **Document mylab ↔ solti-monitoring relationship**
   - Add section to collection-level README
   - Explain orchestrator pattern
   - Show example of importing from galaxy collection
   - Reference manage-svc.sh and svc-exec.sh location

### Priority 3: Completeness
4. **Update directory structures in all role READMEs**
   - Show ALL task files, not just main.yml
   - Show ALL template files
   - Add brief description of each file's purpose

5. **Document all extra task files**
   - What they do
   - When to use them
   - How to invoke them

---

## Testing Validation Workflow (Example)

Based on 91-fleur-alloy-test.yml, this pattern should be documented:

```bash
# Step 1: Test configuration changes
ansible-playbook -K -i inventory.yml playbooks/fleur/91-fleur-alloy-test.yml

# Step 2: Review validation output (automatic in playbook):
#   - Alloy validate results
#   - Diff against production config
#   - Next steps displayed

# Step 3: Deploy if validation passed
ansible-playbook -K -i inventory.yml playbooks/fleur-alloy.yml

# Step 4: Clean up test file
ssh root@fleur.lavnet.net 'rm /tmp/alloy-test-config-*.alloy'
```

---

## Notes

- Only Alloy role currently has test_mode implementation
- Other roles may benefit from similar test mode pattern
- Molecule tests exist but are separate from operational verification tasks
- verify.yml tasks are designed for production verification post-deployment

---

---

## Collection-Level Documentation Review

### solti-monitoring/CLAUDE.md

**Status:** Good overview, but incomplete on operational verification

**What's Covered:**

- Nested git repo structure ✓
- Molecule testing workflow ✓
- Checkpoint commit pattern ✓
- Components listing ✓
- Verification system mentioned (lines 136-142)

**What's Missing:**

- **Orchestration pattern** - Roles designed for orchestration but pattern not explained
- **verify.yml task invocation** - Says "Each role includes verification tasks" but doesn't show HOW to invoke them
- **Molecule verify vs Role verify** - Two different verification systems not distinguished:
  - `molecule verify` → uses `molecule/shared/verify/*.yml` (development/CI testing)
  - Role `verify.yml` → uses `roles/*/tasks/verify.yml` (operational verification in YOUR orchestrator)
- **Test mode pattern** - No mention of alloy_test_mode or safe configuration testing

**Current Text (lines 136-142):**

```markdown
## Verification System

Each role includes verification tasks:
- `verify` - Basic service functionality checks
- `verify1` - Extended integration verification
- Results stored in `verify_output/<distribution>/`
```

**Problem:** This describes WHAT exists but not WHERE or HOW:

- Where are these tasks? (Answer: `roles/*/tasks/verify.yml`)
- How to invoke? (Answer: Include with `tasks_from: verify.yml` in your orchestrator playbooks)
- What's the difference from molecule verify? (Answer: operational vs development testing)

### solti-monitoring/.claude/DEVELOPMENT.md

**Status:** Excellent for development workflow, but focused only on molecule testing

**What's Covered:**

- Capabilities-based testing ✓
- Checkpoint commit patterns ✓
- TDD approach ✓
- Feature flags ✓
- Component integration testing ✓
- Molecule verification workflow ✓

**What's Missing:**

- **Development helper scripts** - manage-svc.sh/svc-exec.sh not documented
- **Script purpose** - No clarification these are DEV tools, not for end users
- **Role-level verify.yml tasks** - Only covers molecule verify, not operational verify
- **Production usage patterns** - How end users consume the collection
- **Test mode patterns** - Doesn't show test mode workflow approach

**Gap:** DEVELOPMENT.md teaches molecule workflow but not the helper scripts or how they relate to production patterns

---

## Critical Documentation Gaps Summary

### Gap 1: Two Verification Systems, One Name

**The Confusion:**

- "Verify" appears in multiple contexts with different meanings
- Documentation doesn't distinguish between them

**The Reality:**

```
Molecule Verify (Development Testing):
  Location: molecule/shared/verify/*.yml
  Purpose: CI/CD and development testing
  Invocation: molecule verify -s podman
  Runs in: Container/VM during molecule test cycle

Role Verify (Operational Verification):
  Location: roles/*/tasks/verify.yml
  Purpose: Production health checks
  Invocation: Include in your orchestrator with tasks_from: verify.yml
  Runs on: Live production systems
```

**Documentation State:**

- CLAUDE.md mentions "verify" but doesn't explain the distinction
- DEVELOPMENT.md only covers molecule verify
- Role READMEs don't mention verify.yml task files

### Gap 2: Development Tools vs Production Usage Confused

**The Reality:**

- **manage-svc.sh/svc-exec.sh**: Development/testing tools for building the collection
  - Quick role testing without building full orchestrator
  - Scaffolding for rapid iteration during role development
  - NOT intended for end-user production orchestration

- **Production usage**: Users build their own orchestrator with standard Ansible playbooks
  - Use collection roles: `jackaltx.solti_monitoring.alloy`
  - Standard playbook patterns with `include_role`, `tasks_from`, etc.

**Documentation State:**

- Role READMEs reference manage-svc.sh/svc-exec.sh prominently
- No clarification that these are DEVELOPMENT tools, not for end users
- Users might think scripts are required for production use
- DEVELOPMENT.md doesn't document these development helpers
- Missing clear separation: "Development workflow" vs "Production usage"

**Impact:**
- Confusion about how to use the collection in production
- Users looking for scripts that aren't in the collection
- Development tools mistaken for required production tooling

### Gap 3: Test Mode Pattern Undocumented

**The Reality:**

- `alloy_test_mode: true` writes config to /tmp without service restart
- Complete test workflow pattern exists (validate → diff → deploy)
- Pattern implemented in production use but not documented

**Test Workflow Pattern:**
  - Generate test config in /tmp
  - Run `alloy validate` on test config
  - Diff test vs production config
  - Display validation results and next steps
  - Deploy only if validation passes

**Documentation State:**

- Not in Alloy README
- Not in CLAUDE.md
- Not in DEVELOPMENT.md
- Only discoverable by reading defaults/main.yml and implementation code

**Impact:** Users may break production by deploying invalid configs without knowing test mode exists

---

## Recommended Documentation Updates

### Priority 1: Clarify Verification Systems

**Update solti-monitoring/CLAUDE.md:**

```markdown
## Verification Systems

### Development Verification (Molecule)
Location: `molecule/shared/verify/*.yml`
Purpose: CI/CD testing during development
Usage: `molecule verify -s podman`

### Operational Verification (Role Tasks)
Location: `roles/*/tasks/verify.yml`
Purpose: Production health checks post-deployment
Usage: Include in your orchestrator playbooks

Example:
  - name: Verify alloy deployment
    include_role:
      name: jackaltx.solti_monitoring.alloy
      tasks_from: verify.yml

Roles with operational verification:
- alloy: verify.yml - Service status, Loki connectivity
- loki: verify.yml, verify1.yml - API health, storage checks
- influxdb: verify.yml - Database connectivity, bucket checks
- wazuh_agent: verify.yml - Agent registration, manager connectivity
```

### Priority 2: Separate Development Tools from Production Usage

**Add to solti-monitoring/CLAUDE.md:**

```markdown
## Production Usage

This collection provides roles for integration into your site-specific orchestration.

**Collection Installation:**
```yaml
ansible-galaxy collection install jackaltx.solti_monitoring
```

**Basic Usage in Playbooks:**
```yaml
- hosts: monitoring_servers
  roles:
    - jackaltx.solti_monitoring.alloy
  vars:
    alloy_loki_endpoints:
      - label: loki01
        endpoint: "10.0.0.11"
```

**Recommended Orchestration Structure:**

Create a separate directory for your lab orchestration:
```
your-lab/
├── inventory.yml           # Your hosts
├── playbooks/
│   ├── deploy-alloy.yml   # Deploy role
│   ├── verify-alloy.yml   # Run verify.yml tasks
│   └── test-alloy.yml     # Test mode playbook
└── group_vars/
    └── monitoring.yml      # Your variables
```

**Invoking Verification Tasks:**
```yaml
# playbooks/verify-alloy.yml
- hosts: monitoring_servers
  tasks:
    - include_role:
        name: jackaltx.solti_monitoring.alloy
        tasks_from: verify.yml
```
```

**Add to solti-monitoring/.claude/DEVELOPMENT.md:**

```markdown
## Development Helper Scripts

For rapid iteration during collection development, helper scripts are available:

**manage-svc.sh** - Quick role deployment testing
```bash
# Deploy a role to test host
./manage-svc.sh alloy deploy

# Remove role from test host
./manage-svc.sh alloy remove
```

**svc-exec.sh** - Execute specific role tasks
```bash
# Run verification tasks
./svc-exec.sh alloy verify

# Run custom task file
./svc-exec.sh alloy verify1
```

**Note:** These scripts are development tools for building/testing the collection.
End users should create their own orchestration playbooks using standard Ansible patterns.

**What these scripts do:**
- Generate temporary playbooks dynamically
- Invoke roles with specific tasks_from entries
- Quick iteration without writing full playbooks
- Useful during molecule development cycles

**Production equivalent:**
Instead of `./svc-exec.sh alloy verify`, users create:
```yaml
# your-lab/playbooks/verify-alloy.yml
- hosts: monitoring
  tasks:
    - include_role:
        name: jackaltx.solti_monitoring.alloy
        tasks_from: verify.yml
```
```

### Priority 3: Document Test Mode in Alloy README

**Add section to solti-monitoring/roles/alloy/README.md:**

```markdown
## Testing Configuration Changes Safely

The role supports test mode to validate configuration changes before deploying to production.

### Test Mode Variables

```yaml
alloy_test_mode: false                # Default: production deployment
alloy_test_config_path: "/tmp/alloy-test-config-{timestamp}.alloy"
```

### Example Test Playbook

Create a test playbook in your orchestration layer:

```yaml
---
- name: Test Alloy configuration changes
  hosts: monitoring_servers
  become: true
  vars:
    alloy_test_mode: true              # Enable test mode
    alloy_monitor_apache: true
    alloy_loki_endpoints:
      - label: monitor11
        endpoint: "10.10.0.11"

  roles:
    - jackaltx.solti_monitoring.alloy

  post_tasks:
    - name: Validate test config
      command: "alloy validate {{ alloy_test_config_path }}"
      register: validation
      failed_when: false

    - name: Compare with production config
      command: "diff -u /etc/alloy/config.alloy {{ alloy_test_config_path }}"
      register: config_diff
      failed_when: false
      changed_when: false

    - name: Display validation results
      debug:
        msg: |
          Validation: {{ 'PASSED' if validation.rc == 0 else 'FAILED' }}
          Config differs: {{ 'YES' if config_diff.rc != 0 else 'NO' }}

          Next: Deploy with production playbook if validation passed
```

**How Test Mode Works:**

1. Config written to /tmp (not /etc/alloy/config.alloy)
2. Service NOT restarted
3. Safe to test breaking changes
4. Validate with `alloy validate` before deploying
5. Compare test vs production config with `diff`
6. Deploy to production only after validation passes
```

---

## Next Steps

Awaiting user input on prioritization and which roles to start with.
