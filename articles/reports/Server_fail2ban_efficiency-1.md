# Alloy Filter Efficiency Report

**Server**: ispconfig_server.example.com
**Time Window**: 2025-12-30 11:38:48 to 2025-12-30 13:38:48 (2 hours)
**Generated**: 2025-12-30 19:42 UTC

## Executive Summary

Over a 2-hour observation period with Bind9 now actively logging to journald, the filtering pattern has changed significantly. Apache filters continue to perform well (80.6% reduction), while journal-based filtering shows unexpected behavior requiring investigation.

| Source | Raw Entries | Filtered (Loki) | Net Change | Efficiency |
|--------|-------------|-----------------|------------|------------|
| systemd journal | 2,175 | 2,548 | -373 | **-17.1%** ⚠️ |
| Apache logs (files) | 1,632 | 316 | +1,316 | **80.6%** ✓ |
| **Total** | **3,807** | **2,864** | **+943** | **24.8%** |

⚠️ **ANOMALY DETECTED**: Journal source shows more entries in Loki than raw journal. This requires investigation.

**Note**: Gitea and Fail2ban logs are collected via systemd journal, not as separate file sources.

## Key Findings

### 1. Bind9 Now Logging (Major Change)

Previous report showed Bind9 with 9,278 raw entries (72% of journal). Current data shows:

- **journalctl count**: 45 entries for named.service
- **Loki count**: 1,328 entries with structured labels
- **Discrepancy**: 1,283 additional entries (2,851% more in Loki)

**Analysis**: Bind9 is now configured and actively logging DNS queries. The classifier is successfully extracting and labeling these queries (event_type: query, notify, transfer, dnssec, etc.), but the raw journal query methodology may not be capturing all entries that Alloy sees.

### 2. Apache Filtering: Working Well

Apache file-based filtering shows **80.6% reduction** (1,632 → 316 entries), effectively removing:

- Health check requests (`/server-status?auto`)
- Monitoring endpoints (`/datalogstatus.php`)
- Localhost traffic (127.0.0.1, 127.0.1.1)
- ISPConfig monitoring

### 3. Journal Source Measurement Issue

The journal source shows **negative filtering** (-17.1%), meaning more entries in Loki than in raw journal. This suggests:

- **Possible causes**:
  1. Alloy's loki.source.journal captures entries from multiple sources (systemd journal + syslog imports)
  2. journalctl filtering by time window may miss entries at boundaries
  3. Some services log to syslog which gets imported to journal differently than direct journal logging
  4. Measurement methodology needs refinement

- **Impact**: Cannot accurately measure journal filtering efficiency with current methodology

## Detailed Analysis

### systemd Journal Data

**Raw journal count** (via journalctl): 2,175 entries
**Loki journal entries**: 2,548 entries
**Net change**: -373 entries (-17.1% - more in Loki!)

#### Service Breakdown (Raw Journal)

Top log generators in the raw journal (2-hour window):

| Service | Raw Count | % of Total |
|---------|-----------|------------|
| CRON | 858 | 39.4% |
| Kernel (UFW firewall) | 397 | 18.3% |
| Postfix (smtpd) | 294 | 13.5% |
| Dovecot | 180 | 8.3% |
| Postfix (submission) | 123 | 5.7% |
| SSH (sshd) | 50 | 2.3% |
| **Bind9 (named)** | **45** | **2.1%** |
| Telegraf | 18 | 0.8% |
| Other | 210 | 9.7% |

**Key Observations**:

- **CRON dominates** at 39.4% (vs 6.7% in previous report)
- **Bind9 appears quiet** at 2.1% (vs 72.1% in previous report) - but see Loki data below
- **Mail services** (Dovecot + Postfix) account for 27.5%
- **Kernel/firewall** produces 397 entries (18.3%)

#### Loki Journal Data (Structured)

**Top services by entry count in Loki**:

| Service | Loki Count | Notes |
|---------|-----------|-------|
| **Bind9 (named)** | **1,328** | 🔍 Structured with event types (query, notify, transfer, dnssec) |
| Postfix | 371 | Multiple streams (smtpd, submission, anvil, cleanup, lmtp, qmgr) |
| Dovecot | 194 | Mail delivery and IMAP/POP3 |
| Unknown/Other | 370 | Unclassified or low-priority |
| SSH | 102 | Authentication and connection events |
| Kernel | 93 | Firewall blocks, system events |
| Systemd | 30 | Service management |
| Other | 60 | Various system services |

**Bind9 Discrepancy Analysis**:

The 45 raw journal entries vs 1,328 Loki entries for Bind9 suggests:

- Bind9 query logging is active and verbose
- Logs may be going to syslog and imported to journal via different mechanism
- journalctl -u named.service may only show service management messages, not queries
- Alloy's loki.source.journal captures the full stream including syslog imports

**Classifier Labels Applied to Bind9**:

- `event_type: query` (1,128 entries) - DNS queries
- `event_type: notify` (16 entries) - Zone change notifications
- `event_type: transfer` (16 entries) - Zone transfers
- `event_type: dnssec` (5 entries) - DNSSEC operations
- `event_type: zone_operation` (10 entries) - Zone management
- General info/notice (153 entries) - Service messages

#### Journal Transport Breakdown

| Transport | Count | % of Total |
|-----------|-------|------------|
| syslog | 1,692 | 77.8% |
| kernel | 397 | 18.3% |
| journal | 66 | 3.0% |
| stdout | 20 | 0.9% |

### Apache Log Filtering ✓

**Raw entries**: 1,632
**Stored in Loki**: 316
**Reduction**: 1,316 entries (80.6%)

Apache logs show excellent filtering efficiency. The classifier successfully removes:

- Health check requests (`/server-status?auto`)
- Monitoring endpoints (`/datalogstatus.php`)
- Localhost traffic (127.0.0.1, ::1)
- ISPConfig monitoring (127.0.1.1)

**File sources**:

- Access logs: `/var/log/apache2/access.log`, `/var/log/apache2/other_vhosts_access.log`
- Error logs: `/var/log/apache2/error.log`

**Loki streams**: 155 separate streams (155 different label combinations)

## Methodology

### Time Window Calculation

```bash
END_TIME=$(date +%s)                    # 1767123528 (2025-12-30 13:38:48 UTC)
START_TIME=$((END_TIME - 7200))         # 1767116328 (2025-12-30 11:38:48 UTC)
START_JOURNAL="2025-12-30 11:38:48"
END_JOURNAL="2025-12-30 13:38:48"
START_LOKI_NS=1767116328000000000       # nanoseconds
END_LOKI_NS=1767123528000000000
```

### Raw Journal Count (on ispconfig_server)

```bash
# Total journal entries
ssh root@ispconfig_server.example.com "journalctl --since='$START_JOURNAL' --until='$END_JOURNAL' --no-pager | wc -l"
# Output: 2175

# Breakdown by transport
ssh root@ispconfig_server.example.com "journalctl --since='$START_JOURNAL' --until='$END_JOURNAL' --output=json --no-pager" | \
  jq -r '._TRANSPORT' | sort | uniq -c | sort -rn

# Breakdown by service
ssh root@ispconfig_server.example.com "journalctl --since='$START_JOURNAL' --until='$END_JOURNAL' --output=json --no-pager" | \
  jq -r '.SYSLOG_IDENTIFIER // ._SYSTEMD_UNIT // "unknown"' | sort | uniq -c | sort -rn | head -20

# Bind9 specific
ssh root@ispconfig_server.example.com "journalctl --since='$START_JOURNAL' --until='$END_JOURNAL' --no-pager -u named.service | wc -l"
# Output: 45
```

### Raw Apache Log Count (on ispconfig_server)

```bash
# Filtered by time window (hours 11, 12, 13 on Dec 30)
ssh root@ispconfig_server.example.com "grep -E '\[30/Dec/2025:(11|12|13):' /var/log/apache2/access.log /var/log/apache2/other_vhosts_access.log /var/log/apache2/error.log 2>/dev/null | wc -l"
# Output: 1632
```

### Loki Query (filtered entries)

```bash
TOKEN=$(cat ~/.secrets/loki_token)

# Journal-sourced entries
curl -G -s -H "Authorization: Bearer $TOKEN" \
  --data-urlencode 'query={hostname="ispconfig_server.example.com", component="loki.source.journal"}' \
  --data-urlencode "start=$START_LOKI_NS" \
  --data-urlencode "end=$END_LOKI_NS" \
  --data-urlencode "limit=5000" \
  http://log-collector.example.com:3100/loki/api/v1/query_range | \
  python3 -c "import sys, json; data = json.load(sys.stdin); print(f\"Total: {sum(len(s['values']) for s in data['data']['result'])}\"); print(f\"Streams: {len(data['data']['result'])}\")"
# Result: 2548 entries across 33 streams

# File-based entries (Apache only)
curl -G -s -H "Authorization: Bearer $TOKEN" \
  --data-urlencode 'query={hostname="ispconfig_server.example.com", job="apache"}' \
  --data-urlencode "start=$START_LOKI_NS" \
  --data-urlencode "end=$END_LOKI_NS" \
  --data-urlencode "limit=5000" \
  http://log-collector.example.com:3100/loki/api/v1/query_range | \
  python3 -c "import sys, json; data = json.load(sys.stdin); print(f\"Total: {sum(len(s['values']) for s in data['data']['result'])}\"); print(f\"Streams: {len(data['data']['result'])}\")"
# Result: 316 entries across 155 streams
```

## Configuration Context

### Active Alloy Monitors on ispconfig_server

From inventory.yml:

```yaml
alloy_monitor_apache: true
alloy_monitor_ispconfig: true
alloy_monitor_fail2ban: true
alloy_monitor_mail: true
alloy_monitor_bind9: true          # ✓ Now actively logging
alloy_monitor_wg: false             # WireGuard disabled
alloy_monitor_gitea: true
```

### Alloy Configuration

- **Source**: `/etc/alloy/config.alloy` (generated from solti-monitoring role)
- **Template**: `solti-monitoring/roles/alloy/templates/client-config.alloy.j2`
- **Loki endpoint**: `http://10.0.0.11:3100` (log-collector via WireGuard)
- **Server args**: `--disable-reporting --server.http.listen-addr=10.0.0.1:12345`

### Active Classifiers

**Journal-based** (via loki.source.journal):

1. **Mail** (`mail-journal-classifier.alloy.j2`): Postfix, Dovecot filtering
2. **Bind9** (`bind9-journal-classifier.alloy.j2`): DNS query/operation filtering with event classification
3. **SSH** (`ssh-journal-classifier.alloy.j2`): SSH auth event filtering
4. **Cron** (`cron-journal-classifier.alloy.j2`): ISPConfig cron noise filtering (if enabled)

**File-based** (via loki.source.file):

1. **Apache** (`apache.alloy.j2`): Access/error log filtering from `/var/log/apache2/` ✓ Working well
2. **ISPConfig** (`apache-ispconfig.alloy.j2`): Site error log filtering (if enabled)

**Note**: While `alloy_monitor_fail2ban` and `alloy_monitor_gitea` are enabled in inventory, these services log to systemd journal and are processed by journal classifiers, not as separate file sources.

## Recommendations

### Immediate Actions

1. **Investigate journal measurement discrepancy** ⚠️ HIGH PRIORITY
   - Raw journal shows 2,175 entries but Loki has 2,548
   - Determine if this is a measurement issue or actual data duplication
   - Consider querying Loki for time range to verify alignment
   - Check if syslog imports are being counted differently

2. **Validate Bind9 classifier effectiveness**
   - Now that Bind9 is logging (1,328 queries in 2 hours), verify classifier is:
     - Dropping routine queries appropriately
     - Retaining security-relevant events (DNSSEC failures, zone transfer issues, query anomalies)
     - Not creating duplicates or false positives

3. **Refine measurement methodology**
   - Document exact Loki query vs journalctl comparison
   - Consider using Loki API to get actual time range of stored data
   - Test if `journalctl --output=export` provides more accurate counts

### Next Sprint

1. **Drill into individual service filtering**:
   - Mail classifier performance (Dovecot + Postfix 565 entries → ? filtered)
   - Bind9 filter validation (1,328 queries → validate retention policy)
   - CRON noise reduction (858 entries → should be heavily filtered)
   - SSH authentication event retention

2. **Bind9 query analysis**:
   - Sample query logs to understand traffic patterns
   - Identify potential DNS abuse or anomalies
   - Tune classifier to reduce noise while keeping security events

3. **Establish new baseline**:
   - Previous baseline (69% reduction) was measured when Bind9 wasn't logging
   - New baseline needs accurate measurement methodology
   - Target: Maintain 60-70% reduction with Bind9 active

### Long-term

1. **Automated reporting**:
   - Script this process for weekly execution
   - Track filtering efficiency trends over time
   - Alert on anomalies (like negative filtering rates)

2. **Classifier optimization**:
   - Review CRON filtering (858 entries - should reduce significantly)
   - Fine-tune Bind9 query logging (balance verbosity vs visibility)
   - Validate no false negatives on security events

## Appendix: Reference Files

### Local Repository

- **Plan**: `~/.claude/plans/loki-filter-analysis.md`
- **This report**: `articles/reports/Server_fail2ban_efficiency.md`
- **Process doc**: `reports/Loki-Report-Process.md`
- **Anonymization guide**: `articles/ANONYMIZATION_PROCESS.md`
- **Inventory**: `mylab/inventory.yml`

### Alloy Templates (solti-monitoring collection)

- Main config: `roles/alloy/templates/client-config.alloy.j2`
- Mail classifier: `roles/alloy/templates/classifiers/mail-journal-classifier.alloy.j2`
- Bind9 classifier: `roles/alloy/templates/classifiers/bind9-journal-classifier.alloy.j2`
- WireGuard classifier: `roles/alloy/templates/classifiers/wireguard-journal-classifier.alloy.j2`
- SSH classifier: `roles/alloy/templates/classifiers/ssh-journal-classifier.alloy.j2`
- Cron classifier: `roles/alloy/templates/classifiers/cron-journal-classifier.alloy.j2`

### Remote Systems

- **Log source**: ispconfig_server.example.com (SSH as root, nopass)
- **Loki server**: log-collector.example.com:3100
- **Auth**: `~/.secrets/loki_token`

---

## Change Log

### 2025-12-30 (This Report)

- Bind9 now actively logging to journald (1,328 entries vs 45 in raw count)
- Measurement methodology showing anomalies (negative filtering on journal source)
- Apache filtering working well (80.6% reduction)
- CRON now dominates raw journal (39.4% vs 6.7% previously)

### 2025-12-29 (Previous Report)

- Bind9 dominated with 9,278 raw entries (72% of journal) - likely misconfigured
- Overall 69% reduction achieved
- Apache filtering at 78.5%
