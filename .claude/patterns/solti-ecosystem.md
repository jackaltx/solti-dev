# SOLTI Ecosystem Organization

**Purpose**: Understanding the jackaltx coordination repository structure

## Repository Organization

```
/home/lavender/sandbox/ansible/jackaltx/
├── .claude/                        # Claude Code context (SHARED)
│   ├── patterns/                   # Implementation patterns (THIS)
│   └── project-contexts/           # Collection decisions
├── solti-monitoring/               # Independent collection (separate repo)
├── solti-containers/               # Independent collection (separate repo)
├── solti-ensemble/                 # Independent collection (separate repo)
├── solti-platforms/                # Independent collection (separate repo)
├── solti-docs/                     # Documentation collection
├── CLAUDE.md                       # Root coordination context
├── README.md                       # Navigation hub
└── .gitignore                      # Excludes collections (separate repos)
```

## The jackaltx Directory

**Role**: Coordination point for independent SOLTI collections

**Purpose**:
- Central documentation hub
- Shared patterns and architectural decisions
- Integration testing coordination
- Cross-collection context for AI assistants

## Collection Independence

### Each Collection is a Separate GitHub Repo

```
GitHub: jackaltx/solti-monitoring      → Cloned to: ./solti-monitoring/
GitHub: jackaltx/solti-containers      → Cloned to: ./solti-containers/
GitHub: jackaltx/solti-ensemble        → Cloned to: ./solti-ensemble/
GitHub: jackaltx/solti-platforms       → Cloned to: ./solti-platforms/
```

**Key Point**: Collections can be worked on **independently**. You can:
- Clone just one collection
- Develop in isolation
- Push to its own GitHub repo
- Use in other projects standalone

### .gitignore Pattern

```gitignore
# Ignore collection subdirectories (they're separate repos)
solti-monitoring/
solti-containers/
solti-ensemble/
solti-platforms/
```

**Why**: Each collection has its own .git directory and remote.

## Shared Resources

### .claude/ Directory

**Shared across all collections** - contains:

1. **patterns/** - Implementation patterns (state management, role structure)
2. **project-contexts/** - Collection decision documents

**Usage**:
- Collection CLAUDE.md references patterns: `../../.claude/patterns/state-management.md`
- Ensures consistency across collections
- Single source of truth for standards

### Root CLAUDE.md

**Purpose**: Multi-collection coordination context

**Contains**:
- Integration points between collections
- Testing matrix (3 distros × 3 platforms)
- Workflow patterns (conductor → platforms → apps)
- Cross-collection dependencies

## Working with Collections

### Single Collection Development

```bash
# Work on just solti-platforms
cd solti-platforms/
git checkout -b feature/new-role
# ... develop ...
git commit -m "feat: add proxmox_vm role"
git push origin feature/new-role

# No impact on other collections
```

### Multi-Collection Integration

```bash
# Test integration between collections
cd ../
ansible-playbook solti-conductor/integration-test.yml
# Uses: platforms → creates VMs
#       monitoring → deploys to VMs
#       containers → runs test services
```

### Cross-Collection References

**In Documentation**:
```markdown
See pattern: ../../.claude/patterns/state-management.md
Reference: ../solti-containers/roles/influxdb3/tasks/main.yml
```

**In Code**: Collections don't directly reference each other - coordination happens via conductor playbooks.

## Pattern Library Benefits

### For Single Collection

When developing just solti-platforms:
```
solti-platforms/CLAUDE.md references:
  → ../../.claude/patterns/state-management.md  (shared)
  → ../solti-containers/roles/influxdb3/       (reference impl)
```

Can still follow patterns even in isolation.

### For All Collections

When working across collections:
- **Consistent** - All follow same patterns
- **Discoverable** - Patterns documented in one place
- **Maintainable** - Update pattern once, applies everywhere

## Directory Structure by Purpose

### Collections (Independent)

```
solti-{name}/                   # Each is standalone
├── roles/                      # Collection-specific roles
├── playbooks/                  # Collection-specific playbooks
├── CLAUDE.md                   # Collection-specific context
└── .git/                       # Own git repository
```

### Coordination (jackaltx root)

```
jackaltx/
├── .claude/                    # Shared resources
│   ├── patterns/               # Cross-collection patterns
│   └── project-contexts/       # Architectural decisions
├── CLAUDE.md                   # Integration context
└── README.md                   # Navigation hub
```

## Workflow Example

### Starting New Collection

```bash
cd /home/lavender/sandbox/ansible/jackaltx

# Create new collection
ansible-galaxy collection init jackaltx.solti_newcollection

# Rename to use hyphens
mv jackaltx/solti_newcollection solti-newcollection

# Add to .gitignore
echo "solti-newcollection/" >> .gitignore

# Reference shared patterns in CLAUDE.md
echo "Patterns: ../../.claude/patterns/" >> solti-newcollection/CLAUDE.md

# Initialize git repo
cd solti-newcollection
git init
git remote add origin git@github.com:jackaltx/solti-newcollection.git
```

### Using Patterns

```bash
cd solti-newcollection/roles

# Read patterns first
cat ../../.claude/patterns/state-management.md

# Study reference implementation
cat ../../solti-containers/roles/influxdb3/tasks/main.yml

# Implement following pattern
# ... create role ...
```

## Integration Points

### Layer Architecture

```
Layer 0: solti-conductor        (Coordination - planned)
         └── Uses: all collections
         └── Location: TBD (separate repo or in jackaltx/)

Layer 1: solti-platforms        (Platform creation)
         └── Independent repo
         └── Creates: VMs, K3s clusters

Layer 2: Applications
         ├── solti-monitoring   (Independent repo)
         ├── solti-containers   (Independent repo)
         └── solti-ensemble     (Independent repo)
```

**Integration**: via conductor playbooks, not direct dependencies.

## Documentation Flow

### Pattern Discovery

1. Collection developer reads patterns: `.claude/patterns/`
2. Implements role following pattern
3. References pattern in role README
4. Pattern becomes self-reinforcing

### Context Loading

**For AI (Claude Code)**:
```
Load for collection work:
1. .claude/patterns/README.md           (patterns overview)
2. collection/CLAUDE.md                 (collection context)
3. .claude/project-contexts/collection-decision.md  (if exists)
```

**For Human**:
```
Navigate via:
1. Root README.md                       (collection index)
2. Collection README.md                 (collection overview)
3. .claude/patterns/                    (implementation guide)
```

## Benefits of This Structure

### Independence
- Collections can be used standalone
- No forced bundling
- Easy to extract and reuse

### Consistency
- Shared patterns ensure quality
- Reference implementations show the way
- Single place to improve standards

### Collaboration
- Each collection has own repo/issues/PRs
- Can have different contributors
- Integration tested at coordination layer

### AI Assistant Friendly
- Context is discoverable
- Patterns are explicit
- References are clear

## Questions

**Q**: Can I use solti-containers without solti-platforms?
**A**: Yes! Each collection is independent. Clone just what you need.

**Q**: Where do patterns live?
**A**: In `jackaltx/.claude/patterns/` - shared across all collections.

**Q**: What if collections have different patterns?
**A**: They shouldn't. Patterns in `.claude/patterns/` are mandatory. If a collection needs a different approach, discuss and update the pattern.

**Q**: Can I develop without cloning all collections?
**A**: Yes, but you'll need jackaltx/.claude/ for patterns. Clone jackaltx, work in your collection subdirectory.

## See Also

- [state-management.md](state-management.md) - How roles manage state
- [role-structure.md](role-structure.md) - Directory layout
- Root CLAUDE.md - Multi-collection coordination
