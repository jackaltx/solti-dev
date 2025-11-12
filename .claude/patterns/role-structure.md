# Role Structure Pattern

**Status**: Mandatory for all SOLTI roles
**Reference**: `solti-containers/roles/influxdb3/`

## Standard Role Layout

```
roles/service_name/
├── tasks/
│   ├── main.yml              # State management (REQUIRED)
│   ├── prerequisites.yml     # Pre-deployment checks
│   ├── deploy.yml            # Deployment logic
│   ├── configure.yml         # Post-deployment config
│   ├── verify.yml            # Health checks (REQUIRED)
│   └── cleanup.yml           # Removal tasks
├── defaults/
│   └── main.yml              # All variables with defaults (REQUIRED)
├── vars/
│   └── distro_name.yml       # Distribution-specific vars (if needed)
├── templates/
│   └── service.conf.j2       # Configuration templates
├── meta/
│   └── main.yml              # Dependencies
└── README.md                 # Role documentation (REQUIRED)
```

## Required Files

### tasks/main.yml

**Must contain**:
1. State validation
2. State-based blocks with visual markers
3. Include statements for sub-tasks

See [state-management.md](state-management.md) for pattern.

### tasks/verify.yml

**Must contain**:
1. Service status check
2. Health endpoint test (if applicable)
3. Basic functionality test
4. Debug output for troubleshooting

**Example**:
```yaml
---
- name: Check service status
  ansible.builtin.systemd:
    name: "{{ service_name }}"
    scope: user
  register: service_status

- name: Wait for service to be ready
  ansible.builtin.uri:
    url: "http://localhost:{{ service_port }}/health"
    status_code: 200
  retries: 10
  delay: 3
```

### defaults/main.yml

**Must contain**:
1. State variable (first)
2. Service identification variables
3. All configurable options with sensible defaults
4. Comments explaining non-obvious settings

**Format**:
```yaml
---
# Role state (prepare, present, absent)
service_state: present

# Service identification
service_name: ct-servicename
service_user: svc-servicename

# Service configuration
service_port: 8080
service_enable_feature: true

# Directories
service_base_dir: "/var/lib/{{ service_name }}"
service_data_dir: "{{ service_base_dir }}/data"
```

### README.md

**Must contain**:
1. Purpose statement
2. Supported distributions/platforms
3. Requirements
4. Variables table
5. Example usage
6. Troubleshooting section

## Optional Files

### vars/distribution.yml

Use when you need distribution-specific values:

```yaml
# vars/rocky9.yml
package_name: rocky-package
service_path: /usr/lib/systemd/system

# vars/debian12.yml
package_name: debian-package
service_path: /lib/systemd/system
```

**Include in main.yml**:
```yaml
- name: Include distribution-specific variables
  ansible.builtin.include_vars: "{{ ansible_distribution | lower }}{{ ansible_distribution_major_version }}.yml"
```

### meta/main.yml

Use when role depends on another role:

```yaml
---
dependencies:
  - role: _base
    vars:
      service_name: "{{ myservice_service_name }}"
      base_dir: "{{ myservice_base_dir }}"
```

## Task File Organization

### Naming Convention

| File | Purpose | When to Use |
|------|---------|-------------|
| `prerequisites.yml` | Pre-flight checks | Verify requirements before deployment |
| `deploy.yml` | Main deployment | Container/service creation |
| `configure.yml` | Post-deployment | Initial configuration, token generation |
| `verify.yml` | Health checks | Always include this |
| `cleanup.yml` | Removal | Stop services, remove files |
| `backup.yml` | Backup logic | Optional, for services with data |

### Task File Pattern

Keep task files focused:

```yaml
# tasks/deploy.yml - single responsibility
---
- name: Deploy quadlet file
  ansible.builtin.template:
    src: service.container.j2
    dest: "~/.config/containers/systemd/{{ service_name }}.container"

- name: Reload systemd
  ansible.builtin.systemd:
    daemon_reload: true
    scope: user

- name: Start service
  ansible.builtin.systemd:
    name: "{{ service_name }}"
    state: started
    scope: user
```

**Don't mix concerns** - deploy.yml shouldn't also configure, verify, etc.

## Variable Naming

### Prefix Convention

All role variables **must** use the role name as prefix:

```yaml
# GOOD
redis_port: 6379
redis_password: "secret"
redis_data_dir: "/var/lib/ct-redis"

# BAD - No prefix
port: 6379
password: "secret"
data_dir: "/var/lib/ct-redis"
```

**Why**: Prevents variable collisions when using multiple roles.

### Naming Pattern

```yaml
{rolename}_{category}_{specifics}

Examples:
redis_service_name          # Service category
redis_service_port
redis_data_dir              # Data category
redis_config_file
redis_enable_auth           # Feature category
redis_enable_persistence
```

## Template Organization

### File Naming

```
templates/
├── service.container.j2       # Quadlet definition
├── service.config.j2          # Main configuration
└── service.env.j2             # Environment file
```

### Template Header

Include context in template:

```jinja
{#
Template: service.container.j2
Purpose: Podman Quadlet definition for {{ service_name }}
State: Used in present state
#}
[Unit]
Description={{ service_description }}
```

## Documentation Standards

### README.md Structure

```markdown
# role_name Role

## Purpose
Brief description of what this role does.

## Features
- Feature 1
- Feature 2

## Requirements
- Requirement 1
- Requirement 2

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `service_state` | `present` | Role state |
| `service_port` | `8080` | Service port |

## Dependencies
List role dependencies or "None"

## Example Usage

\`\`\`yaml
- hosts: localhost
  roles:
    - role: service_name
      vars:
        service_port: 9000
\`\`\`

## Verification

\`\`\`bash
./svc-exec.sh service_name verify
\`\`\`

## Troubleshooting

### Issue 1
Solution 1

## License
MIT

## Author
SOLTI Project
```

## Common Patterns

### Base Role Dependency

Many services depend on `_base` role:

```yaml
# meta/main.yml
dependencies:
  - role: _base
    vars:
      service_name: "{{ myservice_service_name }}"
      service_user: "{{ myservice_user }}"
      base_dir: "{{ myservice_base_dir }}"
      data_dirs: "{{ myservice_data_dirs }}"
```

### Service Properties

Use a service_properties dict for _base role:

```yaml
# defaults/main.yml
service_properties:
  service_name: "{{ myservice_service_name }}"
  service_user: "{{ myservice_user }}"
  service_group: "{{ myservice_group }}"
  base_dir: "{{ myservice_base_dir }}"
  config_dir: config
  data_dir: data
```

## Anti-Patterns

### ❌ DON'T: Mix tasks in main.yml

```yaml
# BAD - All logic in main.yml
- name: Install Service
  when: service_state == 'present'
  block:
    - name: Create user
      user: ...
    - name: Create directories
      file: ...
    - name: Deploy container
      template: ...
    - name: Start service
      systemd: ...
    # 100 more lines...
```

### ✅ DO: Use include_tasks

```yaml
# GOOD - Organized with includes
- name: Install Service
  when: service_state == 'present'
  block:
    - name: Include prerequisites
      ansible.builtin.include_tasks: prerequisites.yml

    - name: Include deployment
      ansible.builtin.include_tasks: deploy.yml

    - name: Include configuration
      ansible.builtin.include_tasks: configure.yml
```

### ❌ DON'T: Hardcode values

```yaml
# BAD
- name: Start redis
  systemd:
    name: ct-redis
    state: started
```

### ✅ DO: Use variables

```yaml
# GOOD
- name: Start {{ service_name }}
  systemd:
    name: "{{ service_name }}"
    state: started
```

## Testing Structure

When adding Molecule tests:

```
roles/service_name/
└── molecule/
    ├── default/
    │   ├── molecule.yml
    │   ├── converge.yml
    │   └── verify.yml
    └── with-feature/
        └── ...
```

## See Also

- [state-management.md](state-management.md) - State pattern
- [examples/influxdb3-annotated.yml](examples/influxdb3-annotated.yml) - Complete example
