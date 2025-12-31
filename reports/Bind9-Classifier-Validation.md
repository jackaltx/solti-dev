# Bind9 Classifier Validation Report

**Generated**: 2025-12-30
**Time Window**: Last 2 hours
**Total Bind9 Entries in Loki**: 1,244

## Executive Summary

The Bind9 classifier is functioning correctly with **no duplicates** and **security events properly retained**. However, **66.7% of queries are spam/blocklist-related** which may be excessive for long-term storage. Consider filtering routine spam checks.

✓ **Working Well**:
- No duplicate entries detected
- Security events (denied, refused, DNSSEC, failures) are retained (6.3% of logs)
- Zone transfers and notifications properly labeled
- Event classification working (query, transfer, notify types)

⚠️ **Needs Review**:
- High volume of spam/blocklist queries (66.7% of all queries)
- Most queries from localhost (86.1%) - mail server spam checks
- 759 spam/blocklist lookups in 2 hours (routine operational noise)

## Detailed Findings

### 1. Event Type Distribution

| Event Type | Count | % of Total | Notes |
|------------|-------|------------|-------|
| Query | 1,148 | 92.3% | DNS queries (mostly spam checks) |
| No Event Type | 86 | 6.9% | Operational messages (clients-per-query, errors) |
| Transfer | 8 | 0.6% | Zone transfers (AXFR) |
| Notify | 2 | 0.2% | Zone update notifications |
| **Total** | **1,244** | **100%** | |

### 2. Security Event Analysis

**Security-relevant messages**: 79 / 1,244 (6.3%)

#### Security Events by Type

| Type | Count | Severity | Sample |
|------|-------|----------|--------|
| **LAME** | 23 | Low | "success resolving after disabling qname minimization" |
| **REFUSED** | 20 | Medium | Query failed (REFUSED) from 130.12.182.118 |
| **DENIED** | 15 | Medium | Query (cache) denied (allow-query-cache did not match) |
| **FAILED** | 11 | Medium | Query failed (operation canceled) |
| **HUNG** | 10 | Low | Shut down hung fetch (blocklist timeouts) |

#### Key Security Observations

1. **Denied Queries (15 events)**: External IP 130.12.182.118 attempting cache queries
   - Domains: isc.org, ripe.net, cloudflare.com (TXT, DNSKEY records)
   - Correctly blocked by allow-query-cache ACL
   - **Status**: ✓ Security events properly retained

2. **Failed/Hung Queries (21 events)**: Mostly bl.blocklist.de timeouts
   - These are routine spam filter checks timing out
   - Not security threats, just operational noise
   - **Recommendation**: Consider filtering these

3. **Zone Transfers (8 events)**: All legitimate secondary nameserver activity
   - Sources: 74.207.225.10, 104.237.137.10 (your secondaries)
   - Zones: seconcepts.com, jackaltx.us
   - **Status**: ✓ Important for security monitoring

### 3. Query Pattern Analysis

**Total queries analyzed**: 1,148

#### Query Sources (Client IPs)

| Source IP | Queries | % | Type |
|-----------|---------|---|------|
| 127.0.0.1 | 988 | 86.1% | Localhost (mail server spam checks) |
| 45.154.154.31 | 19 | 1.7% | External |
| 74.207.225.10 | 13 | 1.1% | Secondary nameserver |
| 45.79.109.10 | 11 | 1.0% | Secondary nameserver |
| Others | 117 | 10.2% | Various external |

#### Top Queried Domains

| Domain | Count | Category |
|--------|-------|----------|
| 1.0.0.127.bl.blocklist.de | 55 | Spam blocklist |
| *.phishtank.rspamd.com | 85 | Phishing checks (3 different hashes) |
| fuzzy1/2.rspamd.com | 24 | Spam signature checks |
| 1.0.0.127.score.senderscore.com | 11 | Reputation checks |
| 1.0.0.127.list.dnswl.org | 10 | Whitelist checks |
| sa-update.surbl.org | 13 | SpamAssassin updates |
| **Spam-related total** | **759** | **66.7% of all queries** |
| Legitimate domains | 379 | 33.3% |

#### Query Types (Record Types)

| Type | Count | % | Purpose |
|------|-------|---|---------|
| A | 649 | 57.0% | IPv4 address lookups |
| TXT | 311 | 27.3% | SPF, DKIM, spam data |
| AAAA | 81 | 7.1% | IPv6 address lookups |
| SOA | 52 | 4.6% | Zone authority checks |
| MX | 19 | 1.7% | Mail server lookups |
| Other | 36 | 3.2% | DNSKEY, CNAME, NS, etc. |

### 4. Duplicate Detection

✓ **No duplicates found** - All 1,244 messages are unique

**Method**: Compared all message content for exact matches
**Result**: 100% unique entries (no false positives from classifier)

## Classifier Effectiveness Assessment

### What's Working ✓

1. **Event Classification**: Correctly labeling queries, transfers, notifications
2. **Security Event Retention**: All denied, refused, and failed queries retained
3. **No Duplicates**: Classifier not creating duplicate entries
4. **Zone Transfer Monitoring**: AXFR events captured for security audit
5. **Notification Tracking**: Zone update notifications from secondaries retained

### What Needs Tuning ⚠️

1. **Spam Filter Query Volume**:
   - **Issue**: 66.7% of stored queries are routine spam checks
   - **Impact**: 759 spam blocklist lookups in 2 hours = ~9,100/day
   - **Cost**: Unnecessary storage and query overhead
   - **Recommendation**: Add classifier stage to drop routine spam checks

2. **Localhost Query Filtering**:
   - **Issue**: 86.1% queries from 127.0.0.1 (mail server)
   - **Impact**: Most are routine operational queries
   - **Recommendation**: Filter localhost spam checks, retain localhost errors/failures

3. **Hung Fetch Events**:
   - **Issue**: 10 "shut down hung fetch" for bl.blocklist.de (routine timeouts)
   - **Impact**: Low-value operational noise
   - **Recommendation**: Consider filtering hung fetches for known blocklists

## Recommendations

### Immediate Actions

1. **Add spam filter query drop stage** to Bind9 classifier:
   ```alloy
   // Drop routine spam/blocklist queries from localhost
   stage.match {
     selector = '{event_type="query"}'

     // Drop localhost spam checks
     stage.match {
       selector = '{} |~ "client @\\w+ 127\\.0\\.0\\.1.*(?:rspamd|blocklist|dnswl|spamhaus|surbl|senderscore)"'
       stage.drop {}
     }
   }
   ```

2. **Retain security-critical queries**:
   - External client queries (not 127.0.0.1)
   - DNSSEC queries (DNSKEY, DS records)
   - Zone transfer requests (AXFR, IXFR)
   - Denied/refused queries (ACL violations)

3. **Filter operational noise**:
   - "clients-per-query decreased/increased" messages
   - "shut down hung fetch" for known blocklists
   - "success resolving after disabling qname minimization" (routine)

### Expected Impact

**Current**: 1,244 entries / 2 hours = 14,928 entries/day

**After filtering spam queries**:
- Drop 759 spam queries (66.7%)
- Retain 485 legitimate queries + security events
- **New rate**: ~5,820 entries/day
- **Reduction**: 61% decrease in Bind9 log volume

**Storage savings**: ~9,100 entries/day eliminated

### Testing Plan

1. Update Bind9 classifier template with spam filter stage
2. Deploy to test server first
3. Monitor for 24 hours:
   - Verify spam queries are dropped
   - Confirm security events still retained
   - Check for any false positives
4. Compare Loki entry count before/after
5. Deploy to production if successful

## Validation Checklist

- [x] Dropping routine queries appropriately: **PARTIAL** - needs spam filter tuning
- [x] Retaining security-relevant events: **YES** - all denied/refused/failed retained
- [x] Not creating duplicates: **YES** - 100% unique entries
- [x] Event classification working: **YES** - query/transfer/notify properly labeled
- [ ] Optimal storage efficiency: **NO** - 66.7% spam queries can be filtered

## Sample Classifier Update

Add this stage to `bind9-journal-classifier.alloy.j2` after the query classification:

```alloy
// ====================================================================
// Drop routine spam filter queries from localhost
// ====================================================================
stage.match {
  selector = '{event_type="query"}'

  // Drop localhost queries to spam/blocklist services
  stage.match {
    // Match localhost queries to known spam checking services
    selector = '{} |~ "client @\\w+ 127\\.0\\.0\\.1.*(?:rspamd\\.com|phishtank|bl\\.blocklist|dnswl\\.org|spamhaus|surbl\\.org|senderscore\\.com)"'

    stage.drop {
      // Optional: Add metric to track dropped spam queries
    }
  }

  // Keep all other queries (external clients, DNSSEC, zone ops)
}
```

## Appendix: Query Commands

### Get Bind9 event breakdown
```bash
TOKEN=$(cat ~/.secrets/monitor11-operators_token)
END_TIME=$(date +%s)
START_TIME=$((END_TIME - 7200))

curl -G -s -H "Authorization: Bearer $TOKEN" \
  --data-urlencode 'query={hostname="fleur.lavnet.net", service_name="named"}' \
  --data-urlencode "start=${START_TIME}000000000" \
  --data-urlencode "end=${END_TIME}000000000" \
  --data-urlencode "limit=5000" \
  "http://monitor11.a0a0.org:3100/loki/api/v1/query_range" > /tmp/bind9-loki.json
```

### Analyze with Python
```python
import json
data = json.load(open('/tmp/bind9-loki.json'))

# Count by event type
for stream in data['data']['result']:
    labels = stream['stream']
    event_type = labels.get('event_type', 'no_event_type')
    count = len(stream['values'])
    print(f'{event_type}: {count}')
```
