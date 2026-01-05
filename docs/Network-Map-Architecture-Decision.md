# Network Map Architecture Decision - Option C

**Date:** 2026-01-05
**Decision:** Master Private → Generated Public approach
**Status:** Approved

## The Decision

Build the complete network map as a **private master version** with full details (mylab, testing-containers, local paths). Create a **sanitization script** to generate a public-safe version later if/when needed.

## Why This Approach

**User requirement:** "I want to not prevent us from creating a sanitized version of this repo for others to follow. This one will always be private."

**Benefits:**
- ✅ Work with full details NOW without compromise
- ✅ No premature public commitment
- ✅ Single source of truth (private master)
- ✅ Automated sanitization when ready
- ✅ No duplicate maintenance

## File Structure

### Private Master (Build This)

```
docs/
├── network-map-full.html                # Complete interactive map
└── solti-network-data-full.json         # All nodes/edges

.claude/
├── generate-network-data.py             # Extract from codebase
├── validate-network.py                  # Completeness checks
├── solti-network-curated.json           # Manual fixes
└── generate-public-map.py               # Sanitization script
```

**Contains:**
- mylab orchestrator and workflows
- testing-containers (if complexity allows)
- Local relative paths (../solti-monitoring/)
- Site-specific deployment examples
- All integration workflows

### Public Generated (Future, Optional)

```
solti-docs/
├── network-map.html                     # Sanitized version
└── solti-network-data.json              # Public-safe data
```

**Sanitization removes:**
- mylab orchestrator nodes/edges
- testing-containers references
- Site-specific workflows
- Local paths → GitHub URLs

**Sanitization converts:**
- `../solti-monitoring/README.md` → `https://github.com/jackaltx/solti-monitoring/blob/main/README.md`
- `../mylab/playbooks/fleur/` → (removed entirely)

## What Gets Built in Each Phase

### Phase 1: MVP (8 hours)
**Location:** `docs/network-map-full.html`
**Nodes:** 15 major nodes (entry, hubs, collections, orchestrator, workflows)
**Features:** Click-to-navigate, search, basic styling

**Includes from start:**
- mylab orchestrator (pink diamond)
- fleur workflow node
- monitor11 workflow node

### Phase 2: Automation (12 hours)
**Add:** Automated data extraction, ~50 role nodes, AI paths

### Phase 3: Workflows (10 hours)
**Add:** Detailed workflow sequences (fleur 10 steps, monitor11 details)

### Phase 4: Polish (16 hours)
**Add:** Filters, export, validation, mobile support

### Phase 5: Public Sanitization (Future, 4 hours)
**Add:** `generate-public-map.py` script
**Output:** `solti-docs/network-map.html` (sanitized)

## Sanitization Script Logic

```python
# .claude/generate-public-map.py

def sanitize_network_data(private_data):
    """Convert private master to public-safe version"""

    public_nodes = []
    public_edges = []

    # Filter nodes
    for node in private_data['nodes']:
        node_id = node['data']['id']

        # Remove private components
        if any(private in node_id for private in ['mylab', 'testing-containers']):
            continue

        # Convert local paths to GitHub URLs
        if 'path' in node['data']:
            path = node['data']['path']
            node['data']['path'] = convert_to_github_url(path)

        # Remove site-specific descriptions
        if 'description' in node['data']:
            node['data']['description'] = sanitize_description(
                node['data']['description']
            )

        public_nodes.append(node)

    # Filter edges (only keep edges between public nodes)
    public_node_ids = {n['data']['id'] for n in public_nodes}
    for edge in private_data['edges']:
        if (edge['data']['source'] in public_node_ids and
            edge['data']['target'] in public_node_ids):
            public_edges.append(edge)

    return {"nodes": public_nodes, "edges": public_edges}

def convert_to_github_url(local_path):
    """Convert ../solti-monitoring/README.md to GitHub URL"""
    mappings = {
        '../solti-monitoring/': 'https://github.com/jackaltx/solti-monitoring/blob/main/',
        '../solti-containers/': 'https://github.com/jackaltx/solti-containers/blob/main/',
        '../solti-ensemble/': 'https://github.com/jackaltx/solti-ensemble/blob/main/',
        '../solti-platforms/': 'https://github.com/jackaltx/solti-platforms/blob/main/',
        '../solti-docs/': 'https://github.com/jackaltx/solti-docs/blob/main/',
    }

    for local, github in mappings.items():
        if local_path.startswith(local):
            return local_path.replace(local, github)

    return local_path
```

## Integration with Existing Docs

### Update Now (Private Master)

**CLAUDE.md:**
```markdown
## Network Visualization

Interactive network map: [docs/network-map-full.html](docs/network-map-full.html)

Shows entire SOLTI ecosystem including:
- Human navigation paths (README.md)
- AI navigation paths (CLAUDE.md)
- Integration workflows (fleur, monitor11)
- mylab orchestration layer
- Cross-collection dependencies

Use for understanding component connections and validating documentation completeness.
```

**docs/README.md:**
```markdown
## Development Tools

### Network Map

[network-map-full.html](network-map-full.html) - Interactive visualization of entire SOLTI system.

**Features:**
- Navigate from solti-docs/README.md to any component
- Trace integration workflows (bare VM → monitored endpoint)
- Validate documentation completeness (no orphans)
- Toggle human vs AI navigation paths
```

### Update Later (Public Release)

**solti-docs/README.md:**
```markdown
# SOLTI Collections

> **🗺️ [Interactive Network Map](network-map.html)** - Visual navigation

Explore the SOLTI architecture interactively.
```

## Workflow

### Development (Now through Phase 4)

```bash
# Work in private master
cd docs/
# Edit network-map-full.html
# Test locally
firefox network-map-full.html
```

### Validation

```bash
# Check for orphans, broken links
python .claude/validate-network.py docs/solti-network-data-full.json
```

### Public Release (Future, When Ready)

```bash
# Generate sanitized version
python .claude/generate-public-map.py

# Output created:
# solti-docs/network-map.html
# solti-docs/solti-network-data.json

# Commit to solti-docs repo
cd solti-docs/
git add network-map.html solti-network-data.json README.md
git commit -m "Add interactive network map"
git push
```

## What Changes in Phase 1

**Previously planned:** Build two versions (public + private) in parallel

**New plan:** Build only private master in Phase 1

**Phase 1 MVP now delivers:**
- Single file: `docs/network-map-full.html`
- Single data file: `docs/solti-network-data-full.json`
- 15 major nodes **including** mylab orchestrator
- Workflow nodes for fleur and monitor11
- Local relative paths (work within workspace)

**Phase 1 does NOT deliver:**
- Public version (deferred to Phase 5)
- Sanitization script (deferred to Phase 5)
- GitHub URL conversion (not needed for private version)

## Implementation Priority

1. **Phase 1-4:** Build complete private master (46 hours)
2. **Phase 5 (optional):** Add sanitization when public release desired (4 hours)

**No pressure to go public** - the private version is the valuable tool for your own navigation and integration work.

## Success Criteria

**Phase 1-4 (Private Master):**
- ✅ Can navigate entire SOLTI system from one entry point
- ✅ All workflows visible (fleur, monitor11)
- ✅ No orphaned documentation
- ✅ Both human and AI paths represented
- ✅ mylab integration clearly shown

**Phase 5 (Public Release, if/when needed):**
- ✅ Sanitization script removes all private references
- ✅ Local paths converted to GitHub URLs
- ✅ Public map works standalone (no workspace dependencies)
- ✅ Automated generation (run script, commit result)

---

**Bottom line:** Build the full private version you need NOW. Option to share a sanitized version LATER if you want. No compromises.
