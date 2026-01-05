# SOLTI Network Map - Implementation Plan

**Status:** Planning Phase
**Created:** 2026-01-05
**Goal:** Create interactive network diagram for traversing entire SOLTI functionality

## Executive Summary

Build an interactive HTML-based network visualization that shows all SOLTI documentation and integration paths. Users can navigate from [solti-docs/README.md](../solti-docs/README.md) to any component, role, or workflow in the system.

**Key Features:**
- Visual graph showing ~120+ documentation files and their connections
- Dual navigation: Human paths (README.md) vs AI paths (CLAUDE.md)
- Integration workflow highlighting (fleur + monitor11 examples)
- Automated completeness validation (find orphaned docs)
- Click nodes to navigate, export as PNG/SVG

## The Problem

**Current State:**
- Documentation spread across 5+ collections
- Some docs orphaned (mylab/, Root CLAUDE.md not linked from entry point)
- Hard to discover integration workflows
- No way to validate completeness (are all docs reachable?)
- Human navigation (README.md) diverges from AI navigation (CLAUDE.md)

**Example Navigation Issues:**
- solti-docs/README.md → ❌ No link to mylab orchestrator
- solti-docs/README.md → ❌ No link to Root CLAUDE.md (most comprehensive doc)
- Hard to trace: "How do I deploy a monitored endpoint?" requires knowing fleur workflow exists

## The Solution

### Technology: Cytoscape.js

Single HTML file with interactive graph visualization:
- **Public version:** `solti-docs/network-map.html` (no mylab/site-specific)
- **Private version:** `docs/network-map-full.html` (includes mylab workflows)

**Why Cytoscape.js:**
- Purpose-built for network graphs
- Zero build step (just HTML + CDN)
- Rich interactions (click, search, filter, export)
- Handles 120+ nodes with hierarchical grouping
- Mobile-friendly

## Visual Design

### Node Types (Color-Coded)

| Type | Shape | Color | Example |
|------|-------|-------|---------|
| Entry Point | ⭐ Star | Red | solti-docs/README.md |
| Hubs | ⬡ Hexagon | Teal | Root CLAUDE.md, Root README.md |
| Collections | ▭ Rounded Rectangle | Light Teal | solti-monitoring, solti-containers |
| Orchestrator | ◆ Diamond | Pink | mylab |
| Workflows | ⬭ Ellipse (dashed) | Purple | fleur deployment, monitor11 setup |
| Roles | ▭ Rectangle | Light Pink | alloy, telegraf, fail2ban |
| Docs | ▭ Small Rectangle | Yellow | Supporting documentation |

### Border Colors (Audience)

- **Green border:** Human navigation (README.md files)
- **Blue border:** AI navigation (CLAUDE.md files)
- **Purple border:** Both audiences

### Edge Types

- **Black solid arrows:** Documentation links
- **Orange thick arrows:** Workflow sequences (with step numbers)
- **Red dashed arrows:** Collection dependencies
- **Gray dotted arrows:** References/citations

## Key Workflows to Highlight

### 1. Fleur Workflow (Bare VM → Monitored Endpoint)

**Path:** `mylab/playbooks/fleur/01-*.yml` through `24-*.yml`

```
01-fleur-create.yml          (solti-platforms: create VM)
  ↓
02-fleur-ssh-harden.yml      (solti-ensemble: sshd_harden)
  ↓
11-fleur-fail2ban.yml        (solti-ensemble: fail2ban)
  ↓
21-fleur-gitea.yml           (solti-ensemble: gitea)
  ↓
22-fleur-alloy.yml           (solti-monitoring: alloy)
  ↓
23-fleur-telegraf.yml        (solti-monitoring: telegraf)
  ↓
24-fleur-bind9-journald.yml  (solti-monitoring: bind9)
```

**Shows:** Complete integration across all 3 collections

### 2. Monitor11 Workflow (Monitoring Server Setup)

**Path:** Clone Proxmox VM → Configure monitoring infrastructure

```
solti-platforms (VM clone)
  ↓
svc-monitor11-metrics.yml  (InfluxDB + Telegraf)
  ↓
svc-monitor11-logs.yml     (Loki + Alloy)
```

**Shows:** Server setup for monitoring infrastructure

### 3. Testing-Containers

**Note:** Builds Docker containers for testing (separate concern, may not include in initial version due to complexity)

## Interactive Features

### What Users Can Do

**Navigation:**
- Click node → Navigate to that file
- Hover node → See tooltip (description, metadata)
- Double-click compound node → Expand/collapse children
- Search box → Find nodes by name

**Filtering:**
- ☑ Human paths (README.md)
- ☑ AI paths (CLAUDE.md)
- ☐ Workflows only
- ☐ Collections only
- Layer depth slider (0-6)

**Export:**
- Download as PNG
- Download as SVG
- Download network data as JSON

**Validation:**
- "Run Validation" button → Highlights orphan nodes in red
- Shows completeness statistics

## Data Generation

### Hybrid Approach

**Automated Extraction (90%):**
- Python script: `.claude/generate-network-data.py`
- Scans all README.md and CLAUDE.md for markdown links
- Parses mylab playbooks for workflow sequences
- Extracts role dependencies from collection metadata

**Manual Curation (10%):**
- File: `.claude/solti-network-curated.json`
- Add semantic connections (e.g., "solti-monitoring depends on solti-ensemble")
- Fix broken path resolutions
- Annotate tooltips/descriptions
- Define workflow groupings

**Merge:**
- Automated + manual (manual overrides automated)
- Output: `solti-network-final.json`

## Completeness Validation

### Automated Checks (`.claude/validate-network.py`)

**Finds:**
1. **Orphan nodes** - No incoming edges (not linked from anywhere)
2. **Broken links** - Edges pointing to missing nodes
3. **Unreachable nodes** - Not reachable from entry point
4. **Incomplete workflows** - Missing sequence steps
5. **Coverage gaps** - Nodes reachable by humans but not AI (or vice versa)

**Output:**
```
✅ Network Validation Report
============================
Graph Statistics:
- Nodes: 127
- Edges: 243

Issues Found: 3
❌ ORPHAN NODES (4)
  - mylab/data/README.md
  - solti-ensemble/roles/mariadb/docs/architecture.md

⚠️  HUMAN-ONLY PATHS (12)
  - Reachable via README.md but not CLAUDE.md
```

## Implementation Phases

### Phase 1: MVP (Week 1) - 8 hours

**Deliverables:**
- `solti-docs/network-map.html` - Basic skeleton
- Manual network data with 15 major nodes (entry + hubs + collections)
- Click-to-navigate working
- Basic styling

**Test:** Can user reach any collection README from entry point?

### Phase 2: Automation (Week 2) - 12 hours

**Deliverables:**
- `.claude/generate-network-data.py` - Automated extraction
- Add ~50 role nodes
- Add AI paths (CLAUDE.md links)
- Merge automated + curated data

**Test:** Automated extraction finds 90%+ of nodes

### Phase 3: Workflows (Week 3) - 10 hours

**Deliverables:**
- Extract fleur + monitor11 workflows
- Orange workflow edges with step labels
- Compound workflow nodes (grouping)
- `docs/network-map-full.html` - Private version with mylab

**Test:** Can trace fleur workflow from bare VM to monitored endpoint?

### Phase 4: Polish (Week 4) - 16 hours

**Deliverables:**
- Sidebar filters (human/AI, layers, search)
- Export PNG/SVG
- Validation script
- Responsive mobile layout
- Tooltips with metadata
- Documentation updates

**Test:** Find and fix all orphan nodes

### Total Effort: 46 hours (~1.5 weeks full-time)

## Files Created/Modified

### New Files (Phase 1-4)

```
docs/
├── network-map-full.html                # Master version (PRIVATE)
└── solti-network-data-full.json         # Full network data

.claude/
├── generate-network-data.py             # Automated extraction
├── validate-network.py                  # Completeness checks
├── solti-network-curated.json           # Manual annotations
└── generate-public-map.py               # Sanitization script
```

### Modified Files (Now)

```
CLAUDE.md                     # Reference network map in docs/
docs/README.md                # Link to full map
```

### Future Public Release Files (Optional)

```
solti-docs/
├── network-map.html          # Generated public version (no mylab)
├── solti-network-data.json   # Sanitized data
└── README.md                 # Add link to map
```

**Decision:** Build complete private version first. Sanitize for public later if desired.

## Maintenance Strategy

### Automated Regeneration

**Git Hook:** Regenerate network data when markdown/YAML files change

```bash
# .git/hooks/post-merge
python .claude/generate-network-data.py
python .claude/validate-network.py
```

### Monthly Manual Review

**Checklist:**
1. Run validation script
2. Fix orphan nodes (add links or document as intentional)
3. Verify workflow sequences still accurate
4. Update curated annotations
5. Test export features
6. Document in sprint reports

**Time:** ~30 minutes/month

## Success Metrics

**Completeness:**
- ✅ All 15 key coordination docs reachable from entry
- ✅ No orphan nodes (or documented as intentional)
- ✅ Both human and AI paths represented
- ✅ Fleur + monitor11 workflows visualized

**Usability:**
- ✅ Find any role in <5 clicks from entry
- ✅ Mobile rendering works
- ✅ Export generates valid images

**Maintainability:**
- ✅ 90%+ automation of node/edge extraction
- ✅ Validation runs automatically
- ✅ Monthly maintenance <30 minutes

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Data extraction errors** | Broken links, missing nodes | Manual validation pass, automated tests |
| **Performance (120+ nodes)** | Slow rendering | Hierarchical collapsing, lazy-load |
| **Maintenance burden** | Stale data | Automated regeneration, git hooks |
| **Mobile usability** | Hard to use on phone | Responsive sizing, touch-optimized |
| **Documentation scale** | Too complex to visualize | Start with high-level view, expand on demand |

## Scope Considerations

### In Scope (Initial Version)

- Entry point, hubs, collections
- Major documentation files (README.md, CLAUDE.md)
- Role documentation (~50 roles)
- Fleur + monitor11 workflows
- Human vs AI path visualization

### Out of Scope (Future Enhancements)

- **testing-containers** - Separate docker container build system (too complex for initial version)
- Test coverage overlay (show which roles have tests)
- Time machine (view network evolution over git history)
- Natural language query ("Show path from mylab to alloy role")
- GitHub Pages integration

### Decision: testing-containers

**User note:** "testing-containers is to build docker containers for testing. It's so much that documentation is a pain."

**Recommendation:** Exclude from initial version due to complexity. Can add later as optional compound node if needed.

## Questions for User

1. **Scope:** Confirm excluding testing-containers from initial version?
2. **Priority:** Start with Phase 1 MVP or full implementation?
3. **Location:** Public map in solti-docs OK? Private map in docs/ OK?
4. **Workflows:** Any other workflows besides fleur/monitor11 to highlight?
5. **Validation:** Run validation monthly or on-demand only?

## Quick Start for Implementation

**To start a fresh conversation for implementation, provide:**

```
I want to implement the SOLTI Network Map per the plan in:
/home/lavender/sandbox/ansible/jackaltx/docs/Network-Map-Implementation-Plan.md

Start with Phase 1 MVP:
- Create solti-docs/network-map.html with Cytoscape.js
- Manual network data with 15 major nodes
- Basic styling and click-to-navigate

Critical files and decisions are documented in the plan.
```

**Plan file locations:**
- **Readable summary:** `/home/lavender/sandbox/ansible/jackaltx/docs/Network-Map-Implementation-Plan.md` (this file)
- **Detailed plan:** `/home/lavender/.claude/plans/cheerful-sparking-lemon.md`

## Next Steps

1. **Review this document** - Take time to think about approach
2. **Decide on scope** - Include/exclude testing-containers?
3. **Approve technology** - Cytoscape.js acceptable?
4. **Start Phase 1** - Build MVP with 15 major nodes
5. **Iterate** - Add complexity incrementally

---

**References:**
- Exploration results in agent outputs (cross-reference analysis, navigation paths)
- Plan agent detailed design (Cytoscape.js implementation specifics)
- Plan file: `.claude/plans/cheerful-sparking-lemon.md`

**Status:** Awaiting user review and approval to proceed
