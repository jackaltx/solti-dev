# Bind9 Journald Integration Plan

**Server**: fleur.lavnet.net
**Objective**: Configure Bind9 to log to journald so Alloy can collect DNS security events
**Created**: 2025-12-30

## Problem Statement

### Current Situation

Bind9 DNS logs are going to `/var/log/syslog` via rsyslog, but Alloy collects from journald:

- **Syslog**: Hundreds of denied cache queries per hour
- **Journald**: Only ~5 Bind9 entries in last 2 hours
- **Alloy**: Configured to read from journald via `loki.source.journal`
- **Result**: Missing ~98% of DNS security events

**Evidence**:
```bash
# Syslog shows denied queries
$ ssh root@fleur.lavnet.net "grep -i 'query.*denied' /var/log/syslog | tail -3"
2025-12-30T16:08:02 fleur named[701]: client @0x... 82.29.53.218#54623 (uu.nl): query (cache) 'uu.nl/ANY/IN' denied
2025-12-30T16:38:09 fleur named[701]: client @0x... 82.29.53.218#49885 (uu.nl): query (cache) 'uu.nl/ANY/IN' denied
2025-12-30T17:08:21 fleur named[701]: client @0x... 82.29.53.218#49625 (uu.nl): query (cache) 'uu.nl/ANY/IN' denied

# Journald has very few
$ ssh root@fleur.lavnet.net "journalctl -u named --since '2 hours ago' | grep -c 'denied'"
5
```

### Why This Matters

1. **Security visibility**: DNS scanners not visible in Loki
2. **Filter evaluation**: Cannot measure Alloy filter efficiency for Bind9
3. **Fail2ban integration**: Future DNS jail needs these logs in journald
4. **Existing infrastructure ready**: bind9-journal-classifier.alloy.j2 already exists and configured

## Solution: Bind9 Native Logging Configuration

Use Bind9's built-in logging channels to send logs to syslog daemon facility, which journald captures on systemd systems.

### Why This Approach

- ✅ Uses Bind9's native logging system (standard configuration)
- ✅ Fine-grained control over log categories
- ✅ Well-documented in Bind9 manuals
- ✅ Doesn't conflict with ISPConfig management
- ✅ Easy to test and revert

## Implementation Steps

### Step 1: Check Current Configuration

```bash
# Check if logging is already configured
ssh root@fleur.lavnet.net "grep -r 'logging' /etc/bind/"

# Check for dedicated logging file
ssh root@fleur.lavnet.net "cat /etc/bind/named.conf.logging 2>/dev/null || echo 'File does not exist'"

# View main configuration
ssh root@fleur.lavnet.net "grep -A10 'logging {' /etc/bind/named.conf* 2>/dev/null || echo 'No logging block found'"
```

### Step 2: Create ISPConfig-Safe Bind9 Logging Configuration

**IMPORTANT**: ISPConfig regenerates `named.conf.local` and `named.conf.options`, so we need a separate file that won't be overwritten.

**File**: `/etc/bind/named.conf.custom` (ISPConfig won't touch this)

```bind
// Custom Bind9 logging configuration for journald integration
// This file is NOT managed by ISPConfig

logging {
    // Define channel that sends to syslog (journald captures this)
    channel journal_channel {
        syslog daemon;          // Syslog facility 'daemon'
        severity info;          // Log level: debug, info, notice, warning, error, critical
        print-time yes;         // Include timestamp
        print-severity yes;     // Include severity level
        print-category yes;     // Include category (queries, security, etc.)
    };

    // Route log categories to journald
    category default { journal_channel; };
    category queries { journal_channel; };       // DNS queries (including denied)
    category security { journal_channel; };      // Security events (TSIG, denied, etc.)
    category dnssec { journal_channel; };        // DNSSEC operations
    category zone-transfer { journal_channel; }; // AXFR/IXFR transfers
    category client { journal_channel; };        // Client requests
    category network { journal_channel; };       // Network operations
    category config { journal_channel; };        // Configuration events
};
```

**Why `/etc/bind/named.conf.custom`**:
- ISPConfig doesn't manage files with `.custom` extension
- Survives ISPConfig updates and zone changes
- Clear naming indicates it's a custom addition

**Key Configuration Points**:
- `syslog daemon` - Uses syslog daemon facility (journald intercepts this on systemd)
- `severity info` - Logs info level and above (can adjust to `debug` for more detail)
- Categories route specific log types to the channel

### Step 3: Include Custom Config in Main named.conf

**File**: `/etc/bind/named.conf` (ISPConfig typically doesn't regenerate the main named.conf)

**Current structure**:
```bind
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
include "/etc/bind/named.conf.default-zones";
```

**Add after the ISPConfig includes**:
```bind
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
include "/etc/bind/named.conf.default-zones";

// Custom logging configuration (not managed by ISPConfig)
include "/etc/bind/named.conf.custom";
```

**Why this approach is ISPConfig-safe**:
- Main `/etc/bind/named.conf` is rarely touched by ISPConfig
- Custom file won't be overwritten by ISPConfig zone/options regeneration
- If ISPConfig updates main named.conf, you can easily re-add the include line

### Step 4: Test Configuration

```bash
# Validate Bind9 configuration syntax
ssh root@fleur.lavnet.net "named-checkconf"

# Should return no output if configuration is valid
# If errors, they'll be displayed - fix before proceeding
```

### Step 5: Apply Configuration

```bash
# Reload Bind9 to apply changes (preferred - no downtime)
ssh root@fleur.lavnet.net "systemctl reload named.service"

# Check service status
ssh root@fleur.lavnet.net "systemctl status named.service"

# If reload doesn't work, restart
ssh root@fleur.lavnet.net "systemctl restart named.service"
```

### Step 6: Verify Logs Flow to Journald

```bash
# Watch journald for new named entries (run in separate terminal)
ssh root@fleur.lavnet.net "journalctl -u named -f"

# In another terminal, count recent entries
ssh root@fleur.lavnet.net "journalctl -u named --since '5 minutes ago' --no-pager | wc -l"

# Should see hundreds of entries per 5 minutes, not just a few

# Check for denied queries in journald
ssh root@fleur.lavnet.net "journalctl -u named --since '5 minutes ago' --no-pager | grep -i denied | head -10"
```

### Step 7: Verify Alloy Collection

Wait a few minutes for Alloy to process logs, then query Loki:

```bash
TOKEN=$(cat ~/.secrets/monitor11-operators_token)

# Check for named logs in Loki
curl -G -s -H "Authorization: Bearer $TOKEN" \
  --data-urlencode 'query={hostname="fleur.lavnet.net", service_name="named"}' \
  --data-urlencode 'limit=10' \
  http://monitor11.a0a0.org:3100/loki/api/v1/query_range | python3 -m json.tool

# Check for DNS security events (should now exist)
curl -G -s -H "Authorization: Bearer $TOKEN" \
  --data-urlencode 'query={hostname="fleur.lavnet.net", service_type="dns", event_type="security"}' \
  --data-urlencode 'limit=10' \
  http://monitor11.a0a0.org:3100/loki/api/v1/query_range | python3 -m json.tool
```

## Verification Checklist

- [ ] `named-checkconf` returns no errors
- [ ] `systemctl status named.service` shows active (running)
- [ ] `journalctl -u named -n 100` shows recent log entries
- [ ] Denied cache queries appear in journald (hundreds per hour)
- [ ] Loki query `{service_name="named"}` returns results
- [ ] Loki query `{service_type="dns"}` returns results with correct labels
- [ ] Loki query `{event_type="security"}` shows DNS security events
- [ ] No DNS resolution issues (test with `dig @localhost example.com`)

## Expected Results

### Before
- Journald: ~2.5 named entries/hour
- Loki: No DNS security events (`event_type="security"` returns 2 entries over 2 days)
- Missing scanner activity (82.29.53.218 hitting uu.nl repeatedly)

### After
- Journald: Hundreds of named entries/hour
- Loki: DNS security events visible with proper classification
- Scanner IPs visible: `{service_type="dns", event_type="security"}`
- Filter efficiency measurable

## Rollback Plan

If issues occur:

```bash
# Remove logging configuration
ssh root@fleur.lavnet.net "rm /etc/bind/named.conf.logging"

# Remove include from main config (if added)
ssh root@fleur.lavnet.net "sed -i '/named.conf.logging/d' /etc/bind/named.conf"

# Reload named
ssh root@fleur.lavnet.net "systemctl reload named.service"

# Logs will revert to default syslog behavior
```

## Files Modified

### On fleur.lavnet.net
- **CREATE**: `/etc/bind/named.conf.logging`
- **MODIFY**: `/etc/bind/named.conf` or `/etc/bind/named.conf.options` (add include)
- **READ-ONLY**: `/etc/bind/named.conf*` (for inspection)

### In Repository (Future Automation)
None yet - user will implement manually first to establish trust.

Potential future locations:
- Ansible playbook: `mylab/playbooks/fleur/bind9-logging-config.yml`
- Or add to existing: `mylab/playbooks/fleur/22-fleur-alloy.yml`

## Related Components

### Already Configured
- **Alloy**: `alloy_monitor_bind9: true` in inventory
- **Classifier**: `solti-monitoring/roles/alloy/templates/classifiers/bind9-journal-classifier.alloy.j2`
- **Fail2ban**: DNS jails exist in `solti-ensemble/roles/fail2ban_config/templates/jail.d/named.conf`

### Will Work After This Change
- Bind9 classifier will receive data and label properly:
  - `service_type="dns"`
  - `event_type="security"` for denied queries
  - `security_type="query_refused"` for cache denials
  - Extracts client_ip, refused_domain for analysis
- Fail2ban DNS jails can detect patterns (future enablement)
- Bad actor detection via UFW + DNS correlation

## Notes

- Bind9 logging to syslog daemon facility is standard practice
- Journald automatically captures syslog facility logs on systemd systems
- This configuration is persistent across Bind9 updates
- ISPConfig typically manages zone files, not logging configuration
- Can adjust `severity` level (debug, info, notice, warning, error) as needed
- Can enable/disable specific categories independently

## References

- Bind9 ARM: https://bind9.readthedocs.io/en/latest/reference.html#logging-statement-grammar
- Existing classifier: `solti-monitoring/roles/alloy/templates/classifiers/bind9-journal-classifier.alloy.j2`
- Current assessment: `Reports/fleur-journald-2wk-assessment.md`
