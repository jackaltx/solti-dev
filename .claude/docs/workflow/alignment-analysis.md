# Workflow Alignment Analysis

## Current State Comparison

### solti-monitoring (Existing)
**Branches**: main, dev (DEFAULT_BRANCH in superlinter)
**Workflows**: 3 files
- ci.yml
- superlinter.yml
- save-container.yml (debug tool)

### solti-containers (New Standard)
**Branches**: main, test
**Workflows**: 3 files
- lint.yml
- superlinter.yml
- ci.yml

---

## Gap Analysis: solti-monitoring vs Standard

### ❌ Missing: lint.yml
solti-monitoring has NO basic lint.yml workflow
- No standalone YAML/Markdown linting
- No ansible-lint job
- No syntax-check job

**Impact**: Less granular feedback, superlinter runs on ALL branches

### ⚠️ Branch Strategy Mismatch
**solti-monitoring**:
- Current branch: `dev`
- superlinter.yml DEFAULT_BRANCH: `dev`
- ci.yml triggers: main, master
- superlinter triggers: `*` (all branches)

**Standard (solti-containers)**:
- Branches: `main`, `test`
- superlinter: test only
- ci.yml: main only (PR)
- lint.yml: both main, test

**Confusion**: Is dev === test? Or is dev a different workflow?

### ⚠️ CI Matrix Disabled
**solti-monitoring ci.yml:36**:
```yaml
platform: ['uut-ct1' ] # , 'uut-ct1', 'uut-ct2']
```
Only 1 of 3 platforms enabled (Rocky 9)

**Standard (solti-containers ci.yml:34)**:
```yaml
platform: ['uut-ct0', 'uut-ct1', 'uut-ct2']
```
All 3 platforms enabled

**Impact**: 33% test coverage vs 100%

### ⚠️ Superlinter Too Broad
**solti-monitoring superlinter.yml:6-7**:
```yaml
branches:
  - '*'
```
Runs on every branch (expensive, noisy)

**Standard (solti-containers superlinter.yml:5-6)**:
```yaml
branches:
  - test
```
Only on development branch

### ⚠️ Wiki Checkout Dependency
**solti-monitoring ci.yml:49-54**:
```yaml
- name: Check out wiki repository
  uses: actions/checkout@v4
  with:
    repository: ${{ github.repository }}.wiki
    path: main/.wiki
    token: ${{ secrets.WIKI_TOKEN }}
```
Requires WIKI_TOKEN secret

**Standard**: No wiki dependency (optional for future)

### ✅ Mature Features Not in Standard
**solti-monitoring has**:
- save-container.yml (debug workflow - saves container state)
- Commented-out GIST/Wiki publishing code
- Elasticsearch reporting hooks
- More sophisticated molecule infrastructure

**Standard lacks these** (intentionally simpler for now)

---

## Alignment Recommendations

### Option 1: Rename dev → test (Recommended)
**Pros**:
- Aligns with new standard
- Clear semantic meaning
- Consistent across collections

**Cons**:
- Git branch rename (breaks existing checkouts)
- Update superlinter DEFAULT_BRANCH

**Actions**:
1. Rename branch: `git branch -m dev test`
2. Update superlinter.yml: DEFAULT_BRANCH: test
3. Restrict superlinter to test branch only
4. Add lint.yml (copy from solti-containers)
5. Enable full 3-platform matrix in ci.yml

### Option 2: Keep dev, Document Difference
**Pros**:
- No breaking changes
- dev has historical meaning

**Cons**:
- Inconsistent with solti-containers
- Confusion when replicating to solti-ensemble

**Actions**:
1. Document: "dev in monitoring === test in other collections"
2. Still add lint.yml
3. Still restrict superlinter to dev only
4. Enable full matrix in ci.yml

### Option 3: Hybrid (Two Development Branches)
**Branches**: main, dev, test
- dev: Long-lived development
- test: Pre-merge integration
- main: Production

**Pros**: Preserves existing workflow, adds formality

**Cons**: More complex, overkill for collection development

---

## Specific Changes Needed for solti-monitoring

### High Priority

1. **Add lint.yml**:
   - Copy from solti-containers
   - Adjust branches: [main, dev] or [main, test]
   - Fast feedback without full superlinter

2. **Restrict superlinter.yml**:
   ```yaml
   # Change from:
   branches: - '*'
   # To:
   branches: - dev  # or - test
   ```

3. **Enable full CI matrix**:
   ```yaml
   # Change from:
   platform: ['uut-ct1']
   # To:
   platform: ['uut-ct0', 'uut-ct1', 'uut-ct2']
   ```

4. **Branch decision**: dev → test or keep dev?

### Medium Priority

5. **Add WORKFLOW_GUIDE.md**:
   - Document branch strategy
   - Explain dev vs main (or test vs main)
   - Local testing instructions

6. **Update superlinter DEFAULT_BRANCH**:
   - Currently: `dev`
   - Should match actual development branch

7. **Review wiki dependency**:
   - Is WIKI_TOKEN always available?
   - Should ci.yml fail if wiki checkout fails?
   - Consider making optional

### Low Priority

8. **Upgrade actions versions**:
   - superlinter: @v3 → @v4 (already noted in comment)
   - Consistent @v4 across all workflows

9. **Consolidate branch names**:
   - ci.yml: [main, master]
   - Choose one: main (recommended)

10. **Re-enable reporting** (future):
    - Uncomment GIST publishing
    - Or implement Mattermost
    - Or commit to Elasticsearch only

---

## Proposed File Changes

### Create: lint.yml
```yaml
name: Lint and Syntax Check

on:
  push:
    branches: [ main, dev ]  # or test
  pull_request:
    branches: [ main, dev ]

jobs:
  yaml-lint:
    # ... (copy from solti-containers)

  markdown-lint:
    # ... (copy from solti-containers)

  ansible-lint:
    # ... (copy from solti-containers)

  syntax-check:
    # ... (copy from solti-containers)
```

### Modify: superlinter.yml
```yaml
on:
  push:
    branches:
      - dev  # Remove '*', restrict to dev
  pull_request:
    branches:
      - dev
  workflow_dispatch:
    # Keep manual trigger

# Also update:
env:
  DEFAULT_BRANCH: dev  # Match your choice
```

### Modify: ci.yml
```yaml
# Line 6: Remove master, keep main
branches: [main]

# Line 36: Enable full matrix
platform: ['uut-ct0', 'uut-ct1', 'uut-ct2']

# Line 38: Increase parallelism
max-parallel: 3  # was 1
```

### Create: .github/WORKFLOW_GUIDE.md
- Adapt from solti-containers
- Document dev (or test) → main flow
- Explain save-container.yml usage
- Document wiki dependency

---

## Decision Points for You

**Question 1**: Branch naming
- **A**: Rename dev → test (align with solti-containers standard)
- **B**: Keep dev (document as equivalent to test)
- **C**: Add test alongside dev (complex, not recommended)

**Question 2**: CI matrix
- **A**: Enable all 3 platforms now (expensive: 3×60min per run)
- **B**: Add scheduled full matrix (nightly/weekly) + PR uses 1 platform
- **C**: Keep 1 platform until infrastructure is more stable

**Question 3**: Superlinter scope
- **A**: Restrict to dev/test branch only (recommended)
- **B**: Keep all branches but make it non-blocking
- **C**: Keep all branches (current)

**Question 4**: Wiki dependency
- **A**: Keep wiki checkout (requires WIKI_TOKEN secret)
- **B**: Make wiki optional (continue-on-error)
- **C**: Remove wiki (simplify like solti-containers)

---

## Summary: What solti-monitoring Needs

**To match standard**:
1. ✅ Add lint.yml (copy from solti-containers)
2. ⚠️ Decide: dev or test branch name
3. ⚠️ Restrict superlinter to dev/test only
4. ⚠️ Enable full 3-platform matrix (or scheduled)
5. ✅ Add WORKFLOW_GUIDE.md

**Already has (keep)**:
- ✅ Mature molecule infrastructure
- ✅ save-container.yml debug tool
- ✅ Elasticsearch reporting hooks
- ✅ ci.yml structure (just needs matrix enabled)

**solti-monitoring is 70% aligned** - mostly needs:
- Branch strategy clarification
- lint.yml addition
- Superlinter scoping
- Matrix enablement
