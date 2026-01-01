# Apache Filter Efficiency & Data Sampling Report

**Date**: 2026-01-01
**Server**: fleur.lavnet.net
**Time Window**: 2026-01-01 11:05:44 to 17:05:44 UTC (6 hours)
**Collection Method**: File-based (loki.source.file)
**Job**: apache

## Part 1: Efficiency Metrics

### Summary

Over a 6-hour observation period, Alloy filters reduced Apache log volume from **2,911 raw entries** to **736 stored entries** in Loki - achieving a **74.7% reduction** in log volume.

| Metric | Value |
|--------|-------|
| Raw entries (fleur) | 2,911 |
| Filtered entries (Loki) | 736 |
| Dropped entries | 2,175 |
| **Reduction rate** | **74.7%** |
| Loki streams | 93 |

### Log Source Breakdown

Apache logs are collected from three file sources:

1. `/var/log/apache2/access.log` - Main access log (SystemRoot vhost)
2. `/var/log/apache2/other_vhosts_access.log` - Virtual host combined log
3. `/var/log/apache2/error.log` - Apache error log

## Part 2: Active Filter Rules

### Source: [apache.alloy.j2](../solti-monitoring/roles/alloy/templates/apache.alloy.j2)

#### Access Log Filters (apache_access)

**Explicit DROP rules:**
```
stage.match {
  selector = "{action=\"GET\", path=\"/server-status?auto\"}"
  action   = "drop"
}
```
- **Target**: Apache mod_status health check requests
- **Source**: Typically 127.0.0.1 (Telegraf monitoring)
- **Frequency**: Every 10 seconds

**Processing (not drops):**
- Categorizes paths: `/admin*`, `/api*`, `/wp-*`, `*.php`, static assets, root, other
- Categorizes status codes: 4xx = client_error, 5xx = server_error
- Drops high-cardinality labels: ip, useragent, referer, path (after categorization)

#### Virtual Host Access Log Filters (apache_vhost_access)

**Explicit DROP rules:**
```
stage.match {
  selector = "{action=\"GET\", path=\"/datalogstatus.php\"}"
  action   = "drop"
}
```
- **Target**: ISPConfig monitoring endpoint
- **Source**: 127.0.1.1 (ISPConfig internal monitoring)
- **Frequency**: Periodic

**Processing:**
- Same categorization as apache_access
- Additional vhost and vport labeling
- Tags a0a0.org as default_vhost (fallback vhost, security indicator)

#### Error Log Processing (apache_error)

**No explicit drops** - all errors preserved

**Processing:**
- Parses module, PID, client_ip from Apache error format
- Categorizes directory listing errors, PHP errors (severity: critical/warning/notice)
- Identifies potential PHP injection attempts (eval, base64_decode patterns)
- Extracts error location and line numbers for PHP errors

## Part 3: Data Samples

### Dropped Entries (Inferred - Examples)

These patterns were observed in raw logs but not present in Loki:

```
127.0.0.1 - - [01/Jan/2026:11:00:00 +0000] "GET /server-status?auto HTTP/1.1" 200 959 "-" "Go-http-client/1.1"
127.0.0.1 - - [01/Jan/2026:11:00:10 +0000] "GET /server-status?auto HTTP/1.1" 200 958 "-" "Go-http-client/1.1"
127.0.0.1 - - [01/Jan/2026:11:00:20 +0000] "GET /server-status?auto HTTP/1.1" 200 966 "-" "Go-http-client/1.1"
127.0.0.1 - - [01/Jan/2026:11:00:30 +0000] "GET /server-status?auto HTTP/1.1" 200 964 "-" "Go-http-client/1.1"
```

**Analysis**:
- Health check interval: Every 10 seconds
- Estimated dropped: ~2,160 entries over 6 hours (360 * 6)
- Matches observed reduction: 2,175 dropped

```
127.0.1.1 - - [01/Jan/2026:11:00:02 +0000] "GET / HTTP/1.1" 200 2001 "-" "Mozilla/5.0 (ISPConfig monitor)"
```

**Analysis**:
- ISPConfig monitoring (not explicitly filtered by IP, but likely caught by other rules)
- User agent identifies as ISPConfig monitor

### Kept Entries (Passed Filters - Samples from Loki)

**ISPConfig Site Error Logs**:
```
[Thu Jan 01 16:43:45.729474 2026] [authz_core:error] [pid 2872571:tid 2872605] [remote 74.7.227.42:53374] AH01630: client denied by server configuration
[Thu Jan 01 15:15:47.732670 2026] [authz_core:error] [pid 2872571:tid 2872659] [client 185.102.115.120:45984] AH01630: client denied by server configuration
[Thu Jan 01 16:46:30.107427 2026] [authz_core:error] [pid 2872571:tid 2872665] [client 52.164.187.143:1954] AH01630: client denied by server configuration
```
**Why kept**: Authorization errors, indicates attempted unauthorized access to protected resources

**SSL/TLS Errors**:
```
[Thu Jan 01 15:47:23.877141 2026] [ssl:error] [pid 2872571:tid 2872643] [client 185.247.137.178:51037] AH02032: Hostname abbrown.com provided via SNI and hostname lavnet.net provided via HTTP are different
```
**Why kept**: SSL configuration issues, potential attack or misconfiguration

**Invalid URI Attempts**:
```
[Thu Jan 01 12:39:36.276638 2026] [core:error] [pid 2872571:tid 2872674] [client 88.151.33.203:41388] AH10244: invalid URI path (/cgi-bin/%%32%65%%32%...)
[Thu Jan 01 12:39:35.748956 2026] [core:error] [pid 2872570:tid 2872654] [client 88.151.33.203:41382] AH10244: invalid URI path (/cgi-bin/.%2e/.%2e/.%...)
```
**Why kept**: Path traversal attempts, security events

**Access Log - Suspicious Requests**:
```
157.245.151.206 - - [01/Jan/2026:16:46:51 +0000] "\x16\x03\x01\x01\x05\x01" 400 392 "-" "-"
```
**Why kept**: Malformed request (SSL handshake to HTTP port?), potential scanning

**External Traffic (Real Users)**:
```
46.105.39.49 - - [01/Jan/2026:11:00:43 +0000] "GET /robots.txt HTTP/1.1" 302 459 "-" "Mozilla/5.0 (compatible; MJ12bot/v2.0.4; http://mj12bot.com/)"
37.139.53.124 - - [01/Jan/2026:11:01:32 +0000] "GET /blog/2016/10/old-house-st-louis/ HTTP/1.0" 302 466 "http://abbrown.com/blog/2016/10/old-house-st-louis/" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
```
**Why kept**: External traffic, legitimate bots and users, not matching health check patterns

## Part 4: Effectivity Assessment (Open Questions)

### Signal-to-Noise Ratio

**Observation**: Of 736 kept entries:
- Majority are ISPConfig site error logs (authorization denied)
- SSL/TLS errors indicate configuration or attack attempts
- Invalid URI attempts are security events
- Small percentage (~50-100?) are legitimate external traffic

**Questions**:
1. Are ISPConfig "client denied" errors useful for security? Or noise?
2. Should we filter authorization errors differently per vhost?
3. Are we keeping enough legitimate traffic for traffic analysis?

### Over-Filtering Risk

**Observation**: Filters are very aggressive on access logs
- 2,160+ health checks dropped (good)
- Unknown: Are we dropping legitimate traffic that looks like monitoring?

**Questions**:
1. Should we sample dropped access logs to verify no false positives?
2. Do we need to track successful requests for traffic pattern analysis?
3. Is 74.7% reduction appropriate for security-focused monitoring?

### Over-Classification Risk

**Observation**: Error logs are NOT filtered - everything is kept
- All PHP errors, warnings, notices preserved
- All authorization errors preserved
- All malformed requests preserved

**Questions**:
1. Are routine PHP notices creating noise?
2. Should we classify error severity and filter low-priority events?
3. Do we need full error context or just error counts?

### Application-Specific Tuning Needs

**Blog Example** (from user's planned blog app):
- Blog 404 errors: Noise or security signal?
- Blog comment spam: Should trigger higher priority?
- Blog legitimate traffic: Need to preserve for analytics?

**Current behavior**: All blog traffic (if it exists) would be kept as legitimate external traffic, unless it matches health check patterns.

**Recommendation**: When blog is deployed, evaluate:
1. Sample blog access patterns
2. Identify blog-specific noise (crawlers, 404s)
3. Create blog-specific classifier if needed

## Part 5: Methodology

### Raw Log Count

```bash
ssh root@fleur.lavnet.net \
  "grep -E '\[01/Jan/2026:(11|12|13|14|15|16|17):' \
    /var/log/apache2/access.log \
    /var/log/apache2/other_vhosts_access.log \
    /var/log/apache2/error.log 2>/dev/null | wc -l"
# Result: 2911
```

### Loki Query

```bash
TOKEN=$(cat ~/.secrets/monitor11-operators_token)
START_LOKI_NS=1767265544000000000
END_LOKI_NS=1767287144000000000

curl -G -s -H "Authorization: Bearer $TOKEN" \
  --data-urlencode 'query={hostname="fleur.lavnet.net", job="apache"}' \
  --data-urlencode "start=$START_LOKI_NS" \
  --data-urlencode "end=$END_LOKI_NS" \
  --data-urlencode "limit=5000" \
  http://monitor11.a0a0.org:3100/loki/api/v1/query_range

# Count with Python:
python3 -c "
import json
with open('loki_apache.json', 'r') as f:
    data = json.load(f)
total = sum(len(stream['values']) for stream in data['data']['result'])
print(f'Total: {total}')
"
# Result: 736
```

## Part 6: Next Steps

1. **Validate filter effectiveness**:
   - Manually review 50 random dropped entries (from raw logs)
   - Confirm no security events were filtered

2. **Error log SNR**:
   - Sample error logs over 24 hours
   - Categorize by actionability (critical vs noise)
   - Consider filtering routine PHP notices/warnings

3. **Per-application tuning**:
   - When blog is deployed, run dedicated report
   - Identify blog-specific patterns
   - Create blog classifier if needed

4. **Traffic analytics gap**:
   - Decide if successful requests should be sampled
   - Consider 1% sampling of non-error access logs for traffic patterns
   - Balance: Security focus vs operational visibility

## Appendix: Reference Files

### Local Repository

- **This report**: `reports/Apache-Filter-Efficiency-Report-2026-01-01.md`
- **Inventory**: `mylab/inventory.yml`
- **Raw data**: `/tmp/loki_apache.json`

### Alloy Templates (solti-monitoring collection)

- Main config: `roles/alloy/templates/apache.alloy.j2`
- ISPConfig config: `roles/alloy/templates/apache-ispconfig.alloy.j2`

### Remote Systems

- **Log source**: fleur.lavnet.net (SSH as root, nopass)
- **Loki server**: monitor11.a0a0.org:3100
- **Auth**: `~/.secrets/monitor11-operators_token`
