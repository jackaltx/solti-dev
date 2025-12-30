# Fleur Alloy Filter Assessment (Journal-Only)

**Server**: fleur.lavnet.net
**Assessment**: 5 random 1-hour samples from available journal data
**Data Source**: systemd journal only (Apache excluded per request)
**Generated**: 2025-12-29

## Data Availability Note

**Journal retention limitation discovered**: Journald logs on fleur only go back **6.6 hours** (since 2025-12-29 15:14:14). Assessment limited to available timeframe.

**Impact**: Cannot assess "two weeks back" or evaluate tuning changes from last week. Recommend configuring longer journal retention for future trend analysis.

## Executive Summary

Statistical analysis of 5 random 1-hour samples shows Alloy journal filters achieve **80.6% reduction** (median: 89.0%, σ: 15.5%). Raw journal volume averages 5,902 entries/hour (median: 6,594), reduced to 932 filtered entries/hour (median: 771).

**Assessment uses actual Loki query data**, not projections.

## Sample Data

| Sample | Time Window | Journal Raw | Loki Filtered | Reduction | Efficiency |
|--------|-------------|-------------|---------------|-----------|------------|
| 4 | 2025-12-29 15:27–16:27 | 7,030 | 771 | 6,259 | 89.0% |
| 3 | 2025-12-29 16:44–17:44 | 6,519 | 1,230 | 5,289 | 81.1% |
| 5 | 2025-12-29 17:46–18:46 | 6,615 | 713 | 5,902 | 89.2% |
| 1 | 2025-12-29 18:55–19:55 | 6,594 | 667 | 5,927 | 89.9% |
| 2 | 2025-12-29 20:42–21:42 | 2,754 | 1,277 | 1,477 | **53.6%** ⚠️ |

## Statistical Summary

### Raw Journal Entries (per hour)

| Metric | Value |
|--------|-------|
| Mean | 5,902 |
| Median | 6,594 |
| Std Dev | 1,771 |

### Filtered Journal Entries (per hour)

| Metric | Value |
|--------|-------|
| Mean | 932 |
| Median | 771 |
| Std Dev | 297 |

### Filter Efficiency

| Metric | Value |
|--------|-------|
| Mean | 80.6% |
| Median | 89.0% |
| Std Dev | 15.5% |

## Observations

### 1. Consistent High Efficiency

Four out of five samples (15:27-19:55) show **81-90% reduction**:
- Sample 4: 89.0%
- Sample 5: 89.2%
- Sample 1: 89.9%
- Sample 3: 81.1%

This indicates stable, effective filtering during afternoon/evening hours.

### 2. Sample 2 Outlier (53.6% Efficiency)

**Time**: 20:42-21:42 (late evening)
**Raw**: 2,754 entries (53% lower than median)
**Filtered**: 1,277 entries (66% higher than median)

**Analysis**:
- Significantly lower raw volume (2,754 vs median 6,594)
- Higher filtered retention (1,277 vs median 771)
- **Hypothesis**: Lower total activity with proportionally more security events requiring retention
  - Less routine Bind9 query noise
  - Similar absolute count of auth failures, SSH attempts, mail events
  - Higher signal-to-noise ratio

### 3. Volume Consistency

Samples 1, 3, 4, 5 show remarkably stable raw volumes (6,519-7,030 range, only 8% variance), suggesting:
- Predictable logging patterns during afternoon/evening
- Consistent Bind9 denied query rate (~6,000-7,000/hour)
- Stable background service activity

### 4. Time-of-Day Pattern

**Afternoon/Evening (15:00-20:00)**: High volume (~6,500-7,000/hour), high efficiency (81-90%)
**Late Evening (20:42-21:42)**: Lower volume (2,754/hour), lower efficiency (53.6%)

Late evening reduction likely due to:
- Decreased DNS scanning activity
- Lower SSH brute-force attempts
- Reduced mail traffic

## Comparison to Previous Assessments

| Assessment | Time Period | Raw/hr | Filtered/hr | Efficiency |
|------------|-------------|--------|-------------|------------|
| Baseline (Dec 29 14:33-16:33) | 2-hour | 6,436 | 2,162 | 66.4% |
| Previous random (Dec 29 16:08-21:39) | 5 samples | 5,327 | 1,057 | 77.8% |
| **Current journal-only (15:27-21:42)** | **5 samples** | **5,902** | **932** | **80.6%** |

**Trend**: Filter efficiency improving or baseline captured heavier Bind9 activity period.

## Filter Performance Breakdown (Inferred)

Based on raw volume composition (from baseline analysis):

**Bind9 DNS** (estimated ~75% of raw volume):
- Expected raw: ~4,400/hour
- Filtered to: ~300/hour (93% reduction)
- Primary noise source: Denied cache queries (177.36.0.0/16)

**Other Services** (SSH, Mail, Cron, System - ~25%):
- Expected raw: ~1,500/hour
- Filtered to: ~630/hour (58% retention)
- Higher retention due to security focus

**Note**: Bind9 appears to be most effective filter (93% reduction), while security-focused services appropriately retain more logs.

## Data Quality

**Actual Loki queries**: All counts from direct Loki API queries
**S3 backend**: Functional (post-http:// endpoint fix)
**No 5000-limit hits**: All samples under query limit
**Journal retention**: Limited to 6.6 hours (see recommendations)

## Assessment Confidence

- **High confidence**: Filter efficiency measurements for available timeframe
- **Low confidence**: Long-term trend analysis (insufficient historical data)
- **Unknown**: Impact of "last week's tuning" (pre-journal retention window)

## Recommendations

### Immediate: Journal Retention Configuration

**Problem**: 6.6 hours of retention insufficient for:
- Weekly trend analysis
- Tuning validation over time
- Root cause analysis of older issues
- Compliance/audit requirements

**Recommendation**: Configure systemd journal retention on fleur:

```bash
# Edit /etc/systemd/journald.conf
SystemMaxUse=2G        # Max disk space
MaxRetentionSec=2week  # Keep 2 weeks

# Apply changes
systemctl restart systemd-journald
```

### Analysis: Sample 2 Anomaly Investigation

Late evening (20:42-21:42) shows unusual pattern. Investigate:
1. Query Loki for security events in that window (fail2ban, SSH auth failures)
2. Check if legitimate security activity or scanning uptick
3. Validate filters aren't over-retaining routine events during low-volume periods

### Future: Multi-Day Assessment

Once journal retention extended:
- Re-run assessment with 5 samples/day over 14 days
- Identify day-of-week patterns
- Validate tuning changes from last week
- Establish baseline variance by time/day

## Appendix: Sample Details

All samples from single day (2025-12-29) spanning 6.3 hours:

- **Early afternoon** (15:27-16:27): 89.0% efficiency
- **Mid afternoon** (16:44-17:44): 81.1% efficiency
- **Late afternoon** (17:46-18:46): 89.2% efficiency
- **Evening** (18:55-19:55): 89.9% efficiency
- **Late evening** (20:42-21:42): 53.6% efficiency ⚠️

**Overall pattern**: Stable high efficiency until late evening volume drop triggers proportional retention increase.
