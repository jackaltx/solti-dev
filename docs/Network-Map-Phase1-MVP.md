# SOLTI Network Map - Phase 1 MVP

**Goal:** Basic interactive network with 15 major nodes
**Effort:** 8 hours
**Output:** `docs/network-map-full.html` (private master version)
**Note:** Building complete private version with mylab/workflows. Public sanitization deferred to future Phase 5.

## What You Get

A single HTML file that shows:

```
                    ⭐ solti-docs/README.md
                    |
        +-----------+-----------+
        |           |           |
    Root README  Root CLAUDE  docs/README
        |           |           |
    +---+---+   +---+---+   +---+
    |   |   |   |   |   |   |
  mon cont ens plat ...    ...
```

**Interactions:**
- Click any node → Navigate to that file
- Hover node → See tooltip
- Drag to pan, scroll to zoom
- Search bar → Find nodes

## The 15 Nodes

### Layer 0: Entry Point (1 node)
- `solti-docs/README.md` - Red star, large

### Layer 1: Hubs (3 nodes)
- `README.md` (root) - Teal hexagon
- `CLAUDE.md` (root) - Teal hexagon
- `docs/README.md` - Teal hexagon

### Layer 2: Collections (5 nodes)
- `solti-monitoring/README.md` - Light teal rounded rectangle
- `solti-containers/README.md` - Light teal rounded rectangle
- `solti-ensemble/README.md` - Light teal rounded rectangle
- `solti-platforms/README.md` - Light teal rounded rectangle
- `solti-docs/README.md` - Light teal rounded rectangle (also the entry point)

### Layer 3: Orchestrator (1 node)
- `mylab/CLAUDE.md` - Pink diamond

### Layer 4: Workflows (2 nodes)
- `fleur workflow` - Purple ellipse (dashed border)
- `monitor11 workflow` - Purple ellipse (dashed border)

### Layer 5: Documentation (3 nodes)
- `solti-docs/solti.md` - Yellow rectangle (philosophy)
- `solti-docs/Development.md` - Yellow rectangle (status)
- `solti-docs/TestingConcept.md` - Yellow rectangle (testing)

## The Links (Edges)

**From solti-docs/README.md:**
- → Root README.md
- → solti.md (philosophy)
- → Development.md
- → TestingConcept.md

**From Root README.md:**
- → solti-monitoring/README.md
- → solti-containers/README.md
- → solti-ensemble/README.md
- → solti-platforms/README.md
- → Root CLAUDE.md
- → docs/README.md

**From Root CLAUDE.md:**
- → mylab/CLAUDE.md
- → fleur workflow
- → monitor11 workflow

**From docs/README.md:**
- → All collections (documentation references)

**Total:** ~30 edges connecting the 15 nodes

## File Structure

```
docs/
├── network-map-full.html                (NEW - complete visualization)
└── solti-network-data-full.json         (NEW - 15 nodes + 30 edges)
```

**Note:** Building in `docs/` not `solti-docs/` since this is the private master version with mylab.

## What network-map.html Contains

Single HTML file (~300 lines):

```html
<!DOCTYPE html>
<html>
<head>
  <title>SOLTI Network Map</title>
  <!-- Cytoscape.js from CDN -->
  <script src="https://unpkg.com/cytoscape@3.28.1/dist/cytoscape.min.js"></script>
  <script src="https://unpkg.com/cytoscape-cola@2.5.1/cytoscape-cola.js"></script>
  <script src="https://unpkg.com/cola@0.5.2/WebCola/cola.min.js"></script>

  <style>
    /* Full viewport graph */
    #cy { width: 100%; height: 100vh; }

    /* Simple search box */
    #search { position: absolute; top: 10px; right: 10px; }
  </style>
</head>
<body>
  <div id="cy"></div>
  <input type="text" id="search" placeholder="Search nodes...">

  <script>
    // Load network data
    fetch('solti-network-data.json')
      .then(res => res.json())
      .then(data => initGraph(data));

    function initGraph(networkData) {
      const cy = cytoscape({
        container: document.getElementById('cy'),
        elements: networkData,

        // Node/edge styling
        style: [
          // Entry point (red star)
          {
            selector: 'node[type="entry"]',
            style: {
              'shape': 'star',
              'background-color': '#FF6B6B',
              'width': 80,
              'height': 80,
              'label': 'data(label)',
              'font-size': 16,
              'font-weight': 'bold',
              'text-valign': 'center',
              'text-halign': 'center'
            }
          },

          // Hubs (teal hexagons)
          {
            selector: 'node[type="hub"]',
            style: {
              'shape': 'hexagon',
              'background-color': '#4ECDC4',
              'width': 60,
              'height': 60,
              'label': 'data(label)'
            }
          },

          // Collections (light teal rounded rectangles)
          {
            selector: 'node[type="collection"]',
            style: {
              'shape': 'roundrectangle',
              'background-color': '#95E1D3',
              'width': 100,
              'height': 40,
              'label': 'data(label)'
            }
          },

          // Orchestrator (pink diamond)
          {
            selector: 'node[type="orchestrator"]',
            style: {
              'shape': 'diamond',
              'background-color': '#F38181',
              'width': 70,
              'height': 70,
              'label': 'data(label)'
            }
          },

          // Workflows (purple ellipses, dashed)
          {
            selector: 'node[type="workflow"]',
            style: {
              'shape': 'ellipse',
              'background-color': '#AA96DA',
              'width': 90,
              'height': 50,
              'border-width': 3,
              'border-style': 'dashed',
              'border-color': '#7B68EE',
              'label': 'data(label)'
            }
          },

          // Docs (yellow rectangles)
          {
            selector: 'node[type="doc"]',
            style: {
              'shape': 'rectangle',
              'background-color': '#FFFFD2',
              'width': 60,
              'height': 25,
              'label': 'data(label)',
              'font-size': 10
            }
          },

          // Edges
          {
            selector: 'edge',
            style: {
              'width': 2,
              'line-color': '#34495E',
              'target-arrow-color': '#34495E',
              'target-arrow-shape': 'triangle',
              'curve-style': 'bezier'
            }
          }
        ],

        // Layout
        layout: {
          name: 'cola',
          animate: true,
          animationDuration: 1000,
          avoidOverlap: true,
          flow: { axis: 'y', minSeparation: 100 }
        }
      });

      // Click to navigate
      cy.on('tap', 'node', function(evt) {
        const node = evt.target;
        const path = node.data('path');
        if (path) {
          window.location.href = path;
        }
      });

      // Search functionality
      document.getElementById('search').addEventListener('input', function(e) {
        const query = e.target.value.toLowerCase();

        cy.nodes().forEach(node => {
          const label = node.data('label').toLowerCase();
          if (label.includes(query)) {
            node.style('opacity', 1);
            node.style('border-width', 3);
            node.style('border-color', '#E74C3C');
          } else {
            node.style('opacity', query ? 0.3 : 1);
            node.style('border-width', 0);
          }
        });
      });
    }
  </script>
</body>
</html>
```

## What solti-network-data.json Contains

```json
{
  "nodes": [
    {
      "data": {
        "id": "solti-docs-readme",
        "label": "solti-docs/README.md",
        "type": "entry",
        "path": "../solti-docs/README.md",
        "description": "Main entry point for SOLTI documentation"
      }
    },
    {
      "data": {
        "id": "root-readme",
        "label": "Root README.md",
        "type": "hub",
        "path": "../README.md",
        "description": "Multi-collection navigation hub"
      }
    },
    {
      "data": {
        "id": "root-claude",
        "label": "Root CLAUDE.md",
        "type": "hub",
        "path": "../CLAUDE.md",
        "description": "Master coordination and troubleshooting guide"
      }
    },
    {
      "data": {
        "id": "docs-readme",
        "label": "docs/README.md",
        "type": "hub",
        "path": "../docs/README.md",
        "description": "Development workspace architecture map"
      }
    },
    {
      "data": {
        "id": "solti-monitoring",
        "label": "solti-monitoring",
        "type": "collection",
        "path": "../solti-monitoring/README.md",
        "description": "Monitoring stack: Telegraf, InfluxDB, Loki, Alloy"
      }
    },
    {
      "data": {
        "id": "solti-containers",
        "label": "solti-containers",
        "type": "collection",
        "path": "../solti-containers/README.md",
        "description": "Container services: Redis, Elasticsearch, Mattermost, etc."
      }
    },
    {
      "data": {
        "id": "solti-ensemble",
        "label": "solti-ensemble",
        "type": "collection",
        "path": "../solti-ensemble/README.md",
        "description": "Infrastructure: MariaDB, security hardening, WireGuard"
      }
    },
    {
      "data": {
        "id": "solti-platforms",
        "label": "solti-platforms",
        "type": "collection",
        "path": "../solti-platforms/README.md",
        "description": "Platform creation: Proxmox VM templates"
      }
    },
    {
      "data": {
        "id": "mylab-claude",
        "label": "mylab orchestrator",
        "type": "orchestrator",
        "path": "../mylab/CLAUDE.md",
        "description": "Site-specific orchestration layer"
      }
    },
    {
      "data": {
        "id": "fleur-workflow",
        "label": "fleur workflow",
        "type": "workflow",
        "path": "../mylab/playbooks/fleur/",
        "description": "Bare VM → ISPConfig → monitored endpoint (10 steps)"
      }
    },
    {
      "data": {
        "id": "monitor11-workflow",
        "label": "monitor11 workflow",
        "type": "workflow",
        "path": "../mylab/playbooks/",
        "description": "Proxmox VM clone → monitoring server setup"
      }
    },
    {
      "data": {
        "id": "solti-md",
        "label": "solti.md",
        "type": "doc",
        "path": "../solti-docs/solti.md",
        "description": "SOLTI philosophy and development journey"
      }
    },
    {
      "data": {
        "id": "development-md",
        "label": "Development.md",
        "type": "doc",
        "path": "../solti-docs/Development.md",
        "description": "Current development status and progress"
      }
    },
    {
      "data": {
        "id": "testing-concept",
        "label": "TestingConcept.md",
        "type": "doc",
        "path": "../solti-docs/TestingConcept.md",
        "description": "Testing methodology and philosophy"
      }
    }
  ],

  "edges": [
    {
      "data": {
        "id": "e1",
        "source": "solti-docs-readme",
        "target": "root-readme"
      }
    },
    {
      "data": {
        "id": "e2",
        "source": "solti-docs-readme",
        "target": "solti-md"
      }
    },
    {
      "data": {
        "id": "e3",
        "source": "solti-docs-readme",
        "target": "development-md"
      }
    },
    {
      "data": {
        "id": "e4",
        "source": "solti-docs-readme",
        "target": "testing-concept"
      }
    },
    {
      "data": {
        "id": "e5",
        "source": "root-readme",
        "target": "solti-monitoring"
      }
    },
    {
      "data": {
        "id": "e6",
        "source": "root-readme",
        "target": "solti-containers"
      }
    },
    {
      "data": {
        "id": "e7",
        "source": "root-readme",
        "target": "solti-ensemble"
      }
    },
    {
      "data": {
        "id": "e8",
        "source": "root-readme",
        "target": "solti-platforms"
      }
    },
    {
      "data": {
        "id": "e9",
        "source": "root-readme",
        "target": "root-claude"
      }
    },
    {
      "data": {
        "id": "e10",
        "source": "root-readme",
        "target": "docs-readme"
      }
    },
    {
      "data": {
        "id": "e11",
        "source": "root-claude",
        "target": "mylab-claude"
      }
    },
    {
      "data": {
        "id": "e12",
        "source": "root-claude",
        "target": "fleur-workflow"
      }
    },
    {
      "data": {
        "id": "e13",
        "source": "root-claude",
        "target": "monitor11-workflow"
      }
    },
    {
      "data": {
        "id": "e14",
        "source": "docs-readme",
        "target": "solti-monitoring"
      }
    },
    {
      "data": {
        "id": "e15",
        "source": "docs-readme",
        "target": "solti-containers"
      }
    },
    {
      "data": {
        "id": "e16",
        "source": "docs-readme",
        "target": "solti-ensemble"
      }
    },
    {
      "data": {
        "id": "e17",
        "source": "docs-readme",
        "target": "solti-platforms"
      }
    }
  ]
}
```

## How to Test It

1. **Create files:**
   ```bash
   cd /home/lavender/sandbox/ansible/jackaltx/docs/
   # Create network-map-full.html (copy HTML above)
   # Create solti-network-data-full.json (copy JSON above)
   ```

2. **Open in browser:**
   ```bash
   firefox network-map-full.html
   # or
   chromium network-map-full.html
   ```

3. **Test interactions:**
   - ✅ See 15 nodes arranged in network
   - ✅ Drag to pan around
   - ✅ Scroll to zoom in/out
   - ✅ Click "Root README.md" → Navigate to ../README.md
   - ✅ Type "monitoring" in search → Highlight matching nodes
   - ✅ Hover nodes → See tooltips

## What's NOT in Phase 1

**Deferred to later phases:**
- Automated data extraction (manual JSON for now)
- 50+ role nodes (just 15 major nodes)
- Filters sidebar (human/AI paths toggle)
- Export PNG/SVG
- Validation script
- Mobile optimization
- Collapsible compound nodes
- Workflow step details (just placeholders)
- Public sanitization (Phase 5, when/if needed)

## Time Breakdown

- Create network-map.html skeleton: 1 hour
- Add Cytoscape.js styling: 2 hours
- Create manual network data JSON: 2 hours
- Implement click-to-navigate: 1 hour
- Add search functionality: 1 hour
- Test and polish: 1 hour

**Total: 8 hours**

## Acceptance Criteria

**Must work:**
- ✅ Open in browser without errors
- ✅ See all 15 nodes clearly labeled
- ✅ Click any node navigates to correct file
- ✅ Search finds and highlights nodes
- ✅ Layout is readable (no overlapping nodes)

**Can be rough:**
- Tooltips optional
- Layout doesn't have to be perfect
- Colors can be adjusted later
- Mobile support can wait

## Next Steps After Phase 1

Once MVP is working:
- **Phase 2:** Add automation (generate JSON from codebase)
- **Phase 3:** Add detailed workflows (fleur 10 steps, monitor11 details)
- **Phase 4:** Polish (filters, export, validation)

---

**This gives you:** A working, clickable private network map in 8 hours with full details (mylab, workflows, local paths). Proves the concept and can be incrementally improved. Public sanitization can be added later (Phase 5) if/when needed.
