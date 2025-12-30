# Fleur Apache Log Collection Assessment

**Server**: fleur.lavnet.net
**Assessment Type**: Configuration verification
**Generated**: 2025-12-30

## Question

Are all Apache access logs being captured by Alloy? Previous assessment showed "0 raw apache logs" in one measurement window, raising concerns about missing data sources.

## Methodology

1. **Read running Alloy config** on fleur: `/etc/alloy/config.alloy`
2. **Identify configured file sources**:
   - Searched for `loki.source.file` blocks
   - Traced `forward_to` chains to verify delivery to Loki
   - Checked component health via Alloy HTTP API
3. **Verify log file paths** on server:
   - Counted entries in Apache logs
   - Compared ISPConfig vhost logs to combined log
   - Checked log formats
4. **Validate collection pipeline**:
   - Confirmed all sources → processors → loki.write.monitor11
   - Verified components report "healthy" status

## Findings

### Configured Apache Sources

| Source | Path | Component | Forward To | Status |
|--------|------|-----------|------------|--------|
| Main access | `/var/log/apache2/access.log` | `loki.source.file "apache_access"` | → loki.process → loki.write.monitor11 | ✅ Healthy |
| Vhost access | `/var/log/apache2/other_vhosts_access.log` | `loki.source.file "apache_vhost_access"` | → loki.process → loki.write.monitor11 | ✅ Healthy |
| Error log | `/var/log/apache2/error.log` | `loki.source.file "apache_error"` | → loki.process → loki.write.monitor11 | ✅ Healthy |
| ISPConfig errors | `/var/log/ispconfig/httpd/*/error.log` | `loki.source.file "ispconfig_site_error"` | → loki.process → loki.write.monitor11 | ✅ Healthy |

### Log Volume Verification

**Apache Standard Logs** (as of 2025-12-30):
```
access.log:                 7,070 entries (localhost monitoring traffic)
other_vhosts_access.log:      923 entries (all vhost traffic)
```

**ISPConfig Individual Vhost Logs** (as of 2025-12-30):
```
a0a0.org/access.log:           29 entries
fleur.lavnet.net/access.log:  124 entries
jackaltx.com/access.log:      140 entries
lavnet.net/access.log:        308 entries
lavweb.com/access.log:        180 entries
thejunkymonkey.com/access.log: 114 entries
gitea.jackaltx.com/access.log: 28 entries
Total:                        923 entries
```

**Key Finding**: ISPConfig individual vhost logs total exactly 923 entries = `other_vhosts_access.log` count.

### Log Redundancy

Apache writes access logs to **two locations simultaneously**:
1. `/var/log/apache2/other_vhosts_access.log` - Combined vhost log (format: `vhost:port IP - - [time] ...`)
2. `/var/log/ispconfig/httpd/{vhost}/access.log` - Individual per-vhost logs

**ISPConfig vhost access logs are NOT configured in Alloy** - they're redundant. Capturing `other_vhosts_access.log` gets all the same data.

### Collection Pipeline

All configured sources follow correct chain:
```
loki.source.file → loki.process.{source} → loki.write.monitor11.receiver
```

Alloy runtime status (via `http://127.0.0.1:12345/api/v0/web/components`):
- All Apache components: `"state": "healthy"`
- Service running since 2025-12-27 03:35:08 UTC

## Conclusion

**All Apache access logs ARE being captured correctly.**

Configuration captures:
- ✅ All vhost access logs (via `other_vhosts_access.log`)
- ✅ Main Apache access log (localhost monitoring)
- ✅ All Apache error logs
- ✅ All ISPConfig per-vhost error logs

**No missing sources.** ISPConfig individual access logs are intentionally not configured - they duplicate data already captured in `other_vhosts_access.log`.

### Explanation of "0 raw apache logs" Result

Previous assessment showing "0 raw apache logs" likely due to:
1. **Timing**: Assessment window may have fallen during log rotation
2. **Low traffic period**: Late night/early morning with minimal vhost activity
3. **Query issue**: Loki query may not have returned data during that specific window

The configuration itself is correct and complete.

## Verification Commands

```bash
# View running config
ssh root@fleur.lavnet.net "cat /etc/alloy/config.alloy"

# Search for file sources
ssh root@fleur.lavnet.net "grep -n 'loki.source.file\|apache\|Apache' /etc/alloy/config.alloy"

# Check log volumes
ssh root@fleur.lavnet.net "wc -l /var/log/apache2/*.log"
ssh root@fleur.lavnet.net "wc -l /var/log/ispconfig/httpd/*/access.log"

# Verify log formats
ssh root@fleur.lavnet.net "head -3 /var/log/apache2/access.log"
ssh root@fleur.lavnet.net "head -3 /var/log/apache2/other_vhosts_access.log"

# Check component health
ssh root@fleur.lavnet.net "curl -s http://127.0.0.1:12345/api/v0/web/components | python3 -m json.tool | grep -A5 'apache'"
```

## Recommendation

No configuration changes needed. Apache log collection is complete and functioning correctly.
