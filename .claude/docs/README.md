# Claude Code Documentation

This directory contains analysis, summaries, and documentation generated during Claude Code sessions.

## Structure

```
.claude/docs/
├── README.md           # This file
└── workflow/           # GitHub workflow standardization
    ├── alignment-analysis.md        # Gap analysis across collections
    ├── deployment-summary.md        # Deployment status and next steps
    └── implementation-summary.md    # Original implementation notes
```

## Workflow Documentation

### alignment-analysis.md
Comprehensive analysis comparing workflow implementations across:
- solti-containers (new standard)
- solti-monitoring (existing, needed alignment)
- solti-platforms (from scratch)

**Key sections**:
- Gap analysis
- Alignment recommendations
- Decision points
- Specific file changes needed

### deployment-summary.md
Post-deployment summary after pushing all test branches:
- GitHub URLs for each collection
- Workflow matrix
- Monitoring instructions
- Next steps
- Known issues

### implementation-summary.md
Original notes from initial workflow standardization in solti-containers:
- Phase-by-phase implementation
- Decisions made
- Testing strategy

## Usage

These documents are for reference and historical context. They help:
- Understand why decisions were made
- Replicate patterns to other collections
- Troubleshoot issues
- Onboard contributors

## Maintenance

Documents are created during Claude Code sessions and should:
- Stay in `.claude/docs/` (not root)
- Be git-tracked for history
- Reference actual file paths
- Include timestamps/context
