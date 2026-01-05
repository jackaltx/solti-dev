# SOLTI Network Map - Sprint Plan

**Purpose:** Break Phase 1-4 into discrete sprints that can be completed independently
**Benefit:** If time runs out, easy handoff to next session with clear continuation point

## Phase 1: MVP - 4 Sprints (8 hours)

### Sprint 1.1: HTML Skeleton + Basic Graph (2 hours)

**Goal:** Get Cytoscape.js rendering with 3 test nodes

**Deliverables:**
- `docs/network-map-full.html` with Cytoscape.js loaded
- 3 hardcoded test nodes (entry point + 2 collections)
- Force-directed layout working
- Can see nodes in browser

**Tasks:**
1. Create HTML file with Cytoscape CDN imports
2. Add 3 test nodes in inline JSON
3. Apply basic styling (different colors for node types)
4. Test in browser - should see 3 connected nodes

**Test:**
```bash
cd docs/
firefox network-map-full.html
# Should see: 3 nodes, can drag/pan, scroll to zoom
```

**Handoff to next sprint:**
- File exists: `docs/network-map-full.html`
- Browser displays 3 nodes successfully
- Ready to add remaining 12 nodes

**Effort:** 2 hours

---

### Sprint 1.2: Complete Node Set (2 hours)

**Goal:** Add all 15 nodes with proper styling

**Deliverables:**
- All 15 nodes defined (entry, hubs, collections, orchestrator, workflows, docs)
- Each node type has correct shape/color
- All ~30 edges defined
- Network fully connected

**Tasks:**
1. Read existing HTML from Sprint 1.1
2. Add remaining 12 nodes to inline JSON
3. Add all edges connecting nodes
4. Test each node type renders correctly
5. Verify network looks hierarchical

**Test:**
```bash
firefox docs/network-map-full.html
# Should see: 15 nodes in network, all connected
# Verify: Entry point (red star), hubs (teal hexagons), etc.
```

**Handoff to next sprint:**
- 15 nodes visible with proper styling
- Network looks organized (not random blob)
- Ready to add interactivity

**Effort:** 2 hours

---

### Sprint 1.3: Click-to-Navigate (2 hours)

**Goal:** Make nodes clickable to navigate to files

**Deliverables:**
- Click any node → Browser navigates to that file
- Relative paths work correctly
- All 15 nodes have working navigation

**Tasks:**
1. Add `path` property to each node's data
2. Implement click handler: `cy.on('tap', 'node', ...)`
3. Test navigation from each node type
4. Fix any broken relative paths
5. Add hover tooltips (bonus if time)

**Test:**
```bash
firefox docs/network-map-full.html
# Click "Root CLAUDE.md" → Should navigate to ../CLAUDE.md
# Click "solti-monitoring" → Should navigate to ../solti-monitoring/README.md
# Test at least 5 different nodes
```

**Handoff to next sprint:**
- All nodes clickable and navigate correctly
- No broken paths
- Ready to add search

**Effort:** 2 hours

---

### Sprint 1.4: Search + Polish (2 hours)

**Goal:** Add search functionality and final touches

**Deliverables:**
- Search box that highlights matching nodes
- Clean layout and styling
- Ready for daily use

**Tasks:**
1. Add search input box to HTML
2. Implement search filter (highlight matches, dim non-matches)
3. Add keyboard shortcut (clear search on Escape)
4. Improve layout (adjust spacing, prevent overlaps)
5. Add basic legend/instructions

**Test:**
```bash
firefox docs/network-map-full.html
# Type "monitoring" → Should highlight solti-monitoring node
# Type "claude" → Should highlight CLAUDE.md nodes
# Press Escape → Should clear search
```

**Handoff to Phase 2:**
- ✅ Phase 1 MVP complete and usable
- File: `docs/network-map-full.html` is self-contained
- Ready to add automation (Phase 2)

**Effort:** 2 hours

---

## Phase 2: Automation - 3 Sprints (12 hours)

### Sprint 2.1: Extract Markdown Links (4 hours)

**Goal:** Auto-generate base network from markdown files

**Deliverables:**
- `.claude/generate-network-data.py` script
- Extracts all README.md and CLAUDE.md files
- Parses markdown links to create edges
- Outputs: `docs/solti-network-base.json`

**Tasks:**
1. Create Python script skeleton
2. Scan for all .md files (exclude venv, .git)
3. Extract `[text](url)` markdown links
4. Create nodes and edges from discovered links
5. Output JSON in Cytoscape format
6. Compare with manual Phase 1 data

**Test:**
```bash
python .claude/generate-network-data.py
# Should create: docs/solti-network-base.json
# Compare node count: manual (15) vs automated (?)
```

**Handoff to next sprint:**
- Script runs without errors
- JSON file generated
- Ready to add role nodes

**Effort:** 4 hours

---

### Sprint 2.2: Add Role Nodes (4 hours)

**Goal:** Extract ~50 role nodes from collections

**Deliverables:**
- Script enhanced to find roles (*/roles/*/README.md)
- Role nodes added to network data
- Edges from collections to their roles
- Network now has ~65 nodes (15 + 50 roles)

**Tasks:**
1. Enhance extraction script to find role READMEs
2. Create role nodes (type="role")
3. Link collections → roles (parent-child)
4. Test with compound nodes (collapsible)
5. Update HTML to handle larger network

**Test:**
```bash
python .claude/generate-network-data.py
# Check output JSON: should have ~65 nodes
# Load in browser: solti-monitoring should expand to show roles
```

**Handoff to next sprint:**
- 50+ role nodes in network
- Collections expandable to show roles
- Ready to merge manual + automated data

**Effort:** 4 hours

---

### Sprint 2.3: Merge Automation + Curation (4 hours)

**Goal:** Combine automated extraction with manual fixes

**Deliverables:**
- `.claude/solti-network-curated.json` - Manual overrides
- Merge script: automated + curated → final
- network-map-full.html uses final merged data
- External data file (not inline)

**Tasks:**
1. Extract inline JSON from network-map-full.html to external file
2. Create curated.json with manual annotations
3. Write merge function (curated overrides automated)
4. Update HTML to load from external JSON
5. Test complete merged network

**Test:**
```bash
python .claude/generate-network-data.py  # Creates base
# Merge with curated
python -c "from generate_network_data import merge; merge()"
# Load in browser - should see full network with annotations
```

**Handoff to Phase 3:**
- ✅ Phase 2 complete - automation working
- Network data external and mergeable
- Ready to add workflow details

**Effort:** 4 hours

---

## Phase 3: Workflows - 2 Sprints (10 hours)

### Sprint 3.1: Fleur Workflow Extraction (5 hours)

**Goal:** Show fleur deployment as 10-step workflow

**Deliverables:**
- Extract fleur playbook sequence (01-*.yml through 24-*.yml)
- Create workflow edges with step numbers
- Orange workflow edges visible
- Can trace: bare VM → monitored endpoint

**Tasks:**
1. Enhance script to parse mylab/playbooks/fleur/
2. Extract numbered playbooks (01, 02, 11, 21, 22, 23, 24, etc.)
3. Extract roles from each playbook (parse YAML)
4. Create sequential workflow edges
5. Add "Workflow Mode" filter to HTML

**Test:**
```bash
# Generate with workflow extraction
python .claude/generate-network-data.py --include-workflows
# Load in browser, enable "Workflow Mode" filter
# Should see: orange path from 01-create → ... → 24-bind9
```

**Handoff to next sprint:**
- Fleur workflow fully extracted
- Workflow Mode filter works
- Ready to add monitor11

**Effort:** 5 hours

---

### Sprint 3.2: Monitor11 + Private Version Complete (5 hours)

**Goal:** Add monitor11 workflow, finalize private version

**Deliverables:**
- Monitor11 workflow extracted (svc-monitor11-*.yml)
- Both workflows highlighted in network
- `docs/network-map-full.html` feature-complete
- Documentation updated (CLAUDE.md, docs/README.md)

**Tasks:**
1. Extract monitor11 playbooks (svc-monitor11-metrics, svc-monitor11-logs)
2. Add to workflow visualization
3. Update docs/README.md with link to network map
4. Update CLAUDE.md with usage instructions
5. Full testing across all features

**Test:**
```bash
# Full regeneration
python .claude/generate-network-data.py --include-workflows --all
# Open in browser, test ALL features:
# - Navigation (click nodes)
# - Search (find nodes)
# - Workflows (trace fleur + monitor11)
# - Filters (toggle workflow mode)
```

**Handoff to Phase 4:**
- ✅ Phase 3 complete - workflows visualized
- Private master version functional
- Ready for polish

**Effort:** 5 hours

---

## Phase 4: Polish - 4 Sprints (16 hours)

### Sprint 4.1: Sidebar Filters (4 hours)

**Goal:** Add professional filter controls

**Deliverables:**
- Sidebar panel with filters
- Toggle: Human paths / AI paths / Workflows
- Layer depth slider (0-6)
- Filter state preserved

**Effort:** 4 hours

---

### Sprint 4.2: Export + Validation (4 hours)

**Goal:** Export PNG/SVG, validate completeness

**Deliverables:**
- Export buttons (PNG, SVG, JSON)
- `.claude/validate-network.py` script
- Validation report (orphans, broken links)

**Effort:** 4 hours

---

### Sprint 4.3: Mobile + Responsive (4 hours)

**Goal:** Works on phones/tablets

**Deliverables:**
- Touch-optimized controls
- Responsive layout
- Mobile-tested on actual device

**Effort:** 4 hours

---

### Sprint 4.4: Documentation + Final Polish (4 hours)

**Goal:** Production-ready

**Deliverables:**
- All docs updated
- Tutorial overlay for first-time users
- Performance optimized
- Ready for daily use

**Effort:** 4 hours

---

## Handoff Protocol

### At End of Each Sprint

**Commit to git:**
```bash
git add docs/network-map-full.html docs/solti-network-data-full.json .claude/
git commit -m "checkpoint: Sprint X.Y complete - [description]"
```

**Create handoff note:**
```bash
echo "Sprint X.Y complete. Next: Sprint X.Y+1" > /tmp/network-map-status.txt
echo "Files: $(ls -1 docs/network-map* .claude/generate-network-data.py 2>/dev/null)" >> /tmp/network-map-status.txt
echo "Test: firefox docs/network-map-full.html" >> /tmp/network-map-status.txt
```

**To continue in new session:**
```
I'm continuing the SOLTI Network Map implementation.

Last completed: Sprint X.Y (see git log)
Next sprint: Sprint X.Y+1

Plan: /home/lavender/sandbox/ansible/jackaltx/docs/Network-Map-Sprint-Plan.md
Current file: docs/network-map-full.html
Status: [check git diff to see what's been done]

Please continue with Sprint X.Y+1.
```

---

## Sprint Summary Table

| Phase | Sprint | Goal | Hours | Deliverable |
|-------|--------|------|-------|-------------|
| 1 | 1.1 | HTML skeleton | 2 | 3 nodes rendering |
| 1 | 1.2 | Complete nodes | 2 | 15 nodes + edges |
| 1 | 1.3 | Click navigation | 2 | All nodes clickable |
| 1 | 1.4 | Search + polish | 2 | MVP complete, usable |
| 2 | 2.1 | Extract markdown | 4 | Auto-generate base |
| 2 | 2.2 | Add roles | 4 | 50+ role nodes |
| 2 | 2.3 | Merge data | 4 | External JSON, merged |
| 3 | 3.1 | Fleur workflow | 5 | 10-step workflow |
| 3 | 3.2 | Monitor11 + done | 5 | Private version complete |
| 4 | 4.1 | Sidebar filters | 4 | Professional controls |
| 4 | 4.2 | Export + validate | 4 | PNG/SVG export |
| 4 | 4.3 | Mobile responsive | 4 | Touch-optimized |
| 4 | 4.4 | Final polish | 4 | Production-ready |

**Total:** 46 hours across 13 sprints (average 3.5 hours per sprint)

**Minimum viable product:** Sprints 1.1-1.4 (8 hours)
**Full private version:** Sprints 1.1-3.2 (28 hours)
**Production polish:** Sprints 4.1-4.4 (16 hours)

---

## Quick Reference

**Start Sprint 1.1:**
```
I want to start Sprint 1.1: HTML Skeleton + Basic Graph

Plan: /home/lavender/sandbox/ansible/jackaltx/docs/Network-Map-Sprint-Plan.md
Goal: Create docs/network-map-full.html with 3 test nodes
Time: 2 hours

Please implement Sprint 1.1 following the sprint plan.
```

**Resume after interruption:**
```
Continuing SOLTI Network Map.

Check status:
git log --oneline -5 docs/network-map-full.html
cat /tmp/network-map-status.txt

Sprint plan: docs/Network-Map-Sprint-Plan.md
Last sprint: [from git log]
Next sprint: [from sprint plan]

Please continue with next sprint.
```
