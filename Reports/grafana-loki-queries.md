# Grafana Loki Query Reference

Quick reference for querying Alloy-processed logs in Grafana.

---

## Apache Path Categorization Verification

### Check Label Values

**View available labels:**
```logql
{hostname="fleur.lavnet.net", job="apache"}
```
Click "Label browser" → should see `path_category` with 7 values, no `path` label

---

### Query by Path Category

**All admin area requests:**
```logql
{hostname="fleur.lavnet.net", job="apache", path_category="admin"}
```

**Static files (images, CSS, JS):**
```logql
{hostname="fleur.lavnet.net", job="apache", path_category="static"}
```

**WordPress requests:**
```logql
{hostname="fleur.lavnet.net", job="apache", path_category="wordpress"}
```

**PHP scripts:**
```logql
{hostname="fleur.lavnet.net", job="apache", path_category="php"}
```

**API requests:**
```logql
{hostname="fleur.lavnet.net", job="apache", path_category="api"}
```

**Root path requests:**
```logql
{hostname="fleur.lavnet.net", job="apache", path_category="root"}
```

**Uncategorized paths:**
```logql
{hostname="fleur.lavnet.net", job="apache", path_category="other"}
```

---

## Cardinality Analysis

### Count Streams per Category

**Streams by path_category (should be ~7 values):**
```promql
count by (path_category) ({hostname="fleur.lavnet.net", job="apache"})
```

**Total Apache streams (should be much lower than before):**
```promql
count({hostname="fleur.lavnet.net", job="apache"})
```

**Streams by vhost and category:**
```promql
count by (vhost, path_category) ({hostname="fleur.lavnet.net", job="apache"})
```

---

## Finding Specific Paths (Message Content)

Path is still in message even though label is dropped:

**Find all requests to specific file:**
```logql
{hostname="fleur.lavnet.net", job="apache", path_category="wordpress"} |= "admin.php"
```

**Find logo image requests:**
```logql
{hostname="fleur.lavnet.net", job="apache", path_category="static"} |= "logo.png"
```

**Extract path from message with regex:**
```logql
{hostname="fleur.lavnet.net", job="apache"}
| regexp `"(?P<method>\w+)\s+(?P<fullpath>\S+)\s+HTTP`
```

---

## Error Analysis by Category

**Client errors (4xx) by path category:**
```logql
{hostname="fleur.lavnet.net", job="apache", error_request="client_error"}
| logfmt
| line_format "{{.path_category}}: {{.status_code}}"
```

**Server errors (5xx) in admin area:**
```logql
{hostname="fleur.lavnet.net", job="apache", path_category="admin", error_request="server_error"}
```

**404 errors by category:**
```logql
{hostname="fleur.lavnet.net", job="apache", status_code="404"}
```

**All errors grouped by category and status:**
```logql
{hostname="fleur.lavnet.net", job="apache", error_request=~"client_error|server_error"}
| logfmt
| line_format "{{.path_category}}: {{.status_code}}"
```

---

## Dashboard Metrics

### Request Distribution Panel

**Requests by category over time:**
```logql
sum by (path_category) (count_over_time({hostname="fleur.lavnet.net", job="apache"}[5m]))
```

**Error rate by category:**
```logql
sum by (path_category) (
  rate({hostname="fleur.lavnet.net", job="apache", error_request=~"client_error|server_error"}[5m])
)
```

**Traffic by vhost and category:**
```logql
sum by (vhost, path_category) (
  count_over_time({hostname="fleur.lavnet.net", job="apache"}[5m])
)
```

---

## Component Label Cleanup Verification

### Mail Logs (should NOT have component)

**Check mail logs have no component label:**
```logql
{hostname="fleur.lavnet.net", service_type="mail"}
```
→ Label browser should NOT show `component`

**Postfix mail logs:**
```logql
{hostname="fleur.lavnet.net", service_type="mail", mail_service="postfix"}
```

**Dovecot mail logs:**
```logql
{hostname="fleur.lavnet.net", service_type="mail", mail_service="dovecot"}
```

---

### Fail2ban Logs (SHOULD have component)

**Check fail2ban has component label:**
```logql
{hostname="fleur.lavnet.net", service_type="fail2ban"}
```
→ Label browser SHOULD show `component` with values: `server`, `actions`, `filter`, `observer`, `jail`

**Fail2ban bans by component:**
```logql
{hostname="fleur.lavnet.net", service_type="fail2ban", action_type="ban"}
```

**Fail2ban server component only:**
```logql
{hostname="fleur.lavnet.net", service_type="fail2ban", component="server"}
```

---

## Mail Service Classification

### Postfix Logs

**All postfix mail:**
```logql
{hostname="fleur.lavnet.net", service_type="mail", mail_service="postfix"}
```

**Postfix auth failures:**
```logql
{hostname="fleur.lavnet.net", service_type="mail", mail_service="postfix", event_type="mail_auth_failure"}
```

**Postfix SMTP protocol:**
```logql
{hostname="fleur.lavnet.net", service_type="mail", mail_service="postfix", protocol="smtp"}
```

---

### Dovecot Logs

**All dovecot mail:**
```logql
{hostname="fleur.lavnet.net", service_type="mail", mail_service="dovecot"}
```

**Dovecot logins:**
```logql
{hostname="fleur.lavnet.net", service_type="mail", mail_service="dovecot", event_type="mail_login"}
```

**Dovecot disconnects:**
```logql
{hostname="fleur.lavnet.net", service_type="mail", mail_service="dovecot", event_type="mail_disconnect"}
```

---

## UFW Firewall Logs

### By Target Service

**SSH blocks:**
```logql
{hostname="fleur.lavnet.net", service_type="firewall", target_service="ssh", event_type="blocked"}
```

**Web traffic:**
```logql
{hostname="fleur.lavnet.net", service_type="firewall", target_service="web"}
```

**Database probes:**
```logql
{hostname="fleur.lavnet.net", service_type="firewall", target_service="database"}
```

**RDP attacks:**
```logql
{hostname="fleur.lavnet.net", service_type="firewall", target_service="rdp"}
```

---

### Security Events

**High-value target blocks:**
```logql
{hostname="fleur.lavnet.net", service_type="firewall", security_event="high_value_target"}
```

**All blocked traffic by target service:**
```logql
sum by (target_service) (
  count_over_time({hostname="fleur.lavnet.net", service_type="firewall", event_type="blocked"}[5m])
)
```

---

## General Query Patterns

### Primary Index Labels

**Always start with these for best performance:**
```logql
{hostname="fleur.lavnet.net", service_type="<service>"}
{hostname="fleur.lavnet.net", job="<source>"}
```

---

### Label Combinations

**Mail + authentication failures:**
```logql
{hostname="fleur.lavnet.net", service_type="mail", event_type="mail_auth_failure"}
```

**Fail2ban + SSH bans:**
```logql
{hostname="fleur.lavnet.net", service_type="fail2ban", action_type="ban", protected_service="ssh"}
```

**Apache + errors:**
```logql
{hostname="fleur.lavnet.net", job="apache", error_request=~"client_error|server_error"}
```

---

## Timestamp-based Queries

### Recent Activity

**Last 5 minutes:**
```logql
{hostname="fleur.lavnet.net", job="apache"} [5m]
```

**Last hour:**
```logql
{hostname="fleur.lavnet.net", job="apache"} [1h]
```

**Last 24 hours:**
```logql
{hostname="fleur.lavnet.net", job="apache"} [24h]
```

---

### Rate Calculations

**Request rate (per second):**
```logql
rate({hostname="fleur.lavnet.net", job="apache"}[5m])
```

**Error rate by category:**
```logql
sum by (path_category) (
  rate({hostname="fleur.lavnet.net", job="apache", error_request=~".*"}[5m])
)
```

---

## Advanced Filtering

### Regex on Message Content

**Find authentication attempts:**
```logql
{hostname="fleur.lavnet.net", service_type="mail"} |~ "authentication"
```

**Exclude monitoring probes:**
```logql
{hostname="fleur.lavnet.net", job="apache"} != "datalogstatus"
```

**Case-insensitive search:**
```logql
{hostname="fleur.lavnet.net", job="apache"} |~ "(?i)error"
```

---

### Label Filtering

**Exclude static files:**
```logql
{hostname="fleur.lavnet.net", job="apache", path_category!="static"}
```

**Multiple categories:**
```logql
{hostname="fleur.lavnet.net", job="apache", path_category=~"admin|api"}
```

**High-priority only:**
```logql
{hostname="fleur.lavnet.net", service_type="fail2ban", alert_level=~"high|critical"}
```

---

## Notes

### Label Cardinality Best Practices

**LOW cardinality (GOOD):**
- `service_type`: ~10 values
- `path_category`: 7 values
- `target_service`: 9 values
- `mail_service`: 2 values

**HIGH cardinality (AVOIDED):**
- ❌ `path`: 1000s of unique URLs
- ❌ `ip`: 1000s of unique IPs (dropped except for security events)
- ❌ `useragent`: 100s of user agents (dropped)

### Query Performance Tips

1. **Always start with hostname + service_type or job**
2. **Use specific labels before regex/grep filters**
3. **Limit time range for large queries**
4. **Use `count_over_time` for metrics instead of raw logs**

---

Generated: 2026-01-01
Last Updated: Session with mail classifier fix, component cleanup, and path categorization
