# Claude Code Documentation

This directory contains analysis, summaries, and documentation generated during Claude Code sessions.

## Structure

```
.claude/docs/
├── README.md           # This file
└── workflow/           # GitHub workflow standardization
    ├── STATUS.md                    # **START HERE** - Current state & gaps
    ├── alignment-analysis.md        # Original gap analysis (pre-implementation)
    ├── deployment-summary.md        # Deployment details and next steps
    └── implementation-summary.md    # Original implementation notes
```

## Workflow Documentation

### STATUS.md ⭐ START HERE
**Current state** of workflow standardization:
- ✅ What's been implemented
- ⚠️ Known issues & limitations
- 🎯 Remaining recommendations
- 📋 Next actions

**Use this** to understand what's done and what's pending.

### alignment-analysis.md (Historical)
Original gap analysis **before** implementation:
- solti-containers (new standard)
- solti-monitoring (existing, needed alignment)
- solti-platforms (from scratch)

**Note**: Pre-implementation analysis. See STATUS.md for current state.

### deployment-summary.md
Post-deployment summary after pushing all test branches:
- GitHub URLs for each collection
- Workflow matrix
- Monitoring instructions
- Next steps
- Known issues

### implementation-summary.md (Historical)
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
