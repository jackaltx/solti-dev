# Sprint Report: Alloy Bind9 Integration & Metrics Exploration
**Date:** 2025-12-31
**Focus:** Bind9 journald integration, metrics collection architecture

## Objectives
1. Integrate Bind9 DNS logs from journald into Alloy pipeline
2. Explore metrics collection from Alloy using stage.metrics
3. Establish Telegraf→Alloy scraping infrastructure

## Outcomes

### ✅ Completed
1. **Bind9 journald integration working**
   - Created comprehensive classifier: [bind9-journal-classifier.alloy.j2](../solti-monitoring/roles/alloy/templates/classifiers/bind9-journal-classifier.alloy.j2)
   - Classifies: zone operations, transfers, queries, DNSSEC, security events
   - Reduces noise: automatic zones, cache cleaning
   - Deployed and running on fleur.lavnet.net

2. **Architecture decision documented**
   - Separated concerns: Alloy+Loki (security) vs Telegraf+InfluxDB (performance)
   - Documented in [METRICS_COLLECTION_STRATEGY.md](../solti-monitoring/docs/METRICS_COLLECTION_STRATEGY.md)

3. **Telegraf scraper infrastructure ready**
   - Template: [prometheus-alloy.conf.j2](../solti-monitoring/roles/telegraf/templates/inputs/prometheus-alloy.conf.j2)
   - Task with conditional deployment
   - Can scrape Alloy's internal operational metrics

### ⚠️ Attempted but Abandoned
**Alloy stage.metrics for Bind9 query metrics**
- **Why attempted:** Generate Prometheus metrics from log parsing
- **Why abandoned:** Runtime pipeline creation errors despite passing validation
- **Decision:** Keep logs (security) separate from metrics (performance)
- **Future approach:** Use Telegraf's native `inputs.bind` plugin for DNS metrics

## Key Learnings

### 1. Alloy Deployment & Debugging

#### Test-First Workflow
```bash
# Always test before production
ansible-playbook playbooks/fleur/91-fleur-alloy-test.yml

# Check validation in test output
# Look for: "✓ VALIDATION: PASSED"

# Deploy only after validation passes
ansible-playbook playbooks/fleur/22-fleur-alloy.yml
```

**Lesson:** The test playbook (`91-*-test.yml`) generates config to `/tmp/`, runs `alloy validate`, and shows diff vs production. This catches syntax errors before deployment.

#### Debugging Failed Alloy Service

**Pattern discovered:**
1. `systemctl status alloy` shows exit code 3 (config error)
2. `journalctl -u alloy` shows truncated errors
3. **Best approach:** `ssh root@fleur "alloy run /etc/alloy/config.alloy"` shows full error with line numbers

**Common errors:**
- Selector syntax: Use double quotes `"{label=\"value\"}"`, not single quotes
- Stage.metrics requires `action` parameter (inc/add)
- Stage.drop requires at least one of: source, expression, older_than, longer_than
- Nested stage.match with action="drop" can't have child stages

#### Config Validation vs Runtime Errors

**Critical discovery:** `alloy validate` checks syntax but NOT runtime pipeline semantics
- Config can pass validation but fail at runtime during `loki.process` pipeline creation
- Always test with actual `alloy run` after validation
- Error messages show selector syntax differently than rendered config (debugging confusion)

### 2. Jinja2 Templating for Alloy

#### Escaping Patterns
```jinja2
# Single backslash in template = single backslash in output
stage.regex {
  expression = "client @\\w+ (?P<ip>[\\d\\.]+)"
}

# Double backslash when inside quoted selector
selector = "{} |~ \"client @\\\\w+ 127\\\\.0\\\\.0\\\\.1\""
```

**Lesson:** Alloy selectors inside LogQL regex need double escaping: `\\\\` for backslash in regex pattern.

#### Conditional Blocks
```jinja2
{% if alloy_bind9_metrics_enabled | default(false) %}
// Metrics code here
{% endif %}
```

**Lesson:** Use `| default(false)` for opt-in features. Defaults in `roles/*/defaults/main.yml` must be `false` for multi-workstation safety.

### 3. Architecture Decisions

#### Separation of Concerns
**Decision:** Keep logs and metrics pipelines separate
- **Alloy+Loki:** Long-term log storage, security events, compliance, search
- **Telegraf+InfluxDB:** Time-series metrics, performance trends, dashboards

**Rationale:**
- Each tool optimized for its purpose
- Simpler to maintain and debug
- Native plugins (e.g., `inputs.bind`) more reliable than log parsing for metrics
- Mixing concerns led to complex debugging (stage.metrics runtime errors)

#### When to Use Log-Derived Metrics
**Good use cases:**
- Counting events (auth failures, errors)
- Tracking application-specific events not exposed via metrics API
- Temporary metrics during development

**Avoid when:**
- Native metrics API exists (use Telegraf plugin instead)
- High cardinality (IP addresses, usernames) - use logs for search, not metrics
- Complex parsing required - error-prone

### 4. Test Workflow Effectiveness

**Test playbook pattern:** `9X-<host>-<service>-test.yml`
```yaml
- name: Service configure (TEST MODE)
  vars:
    alloy_test_mode: true
    alloy_test_config_path: "/tmp/alloy-test-config-{{ ansible_date_time.iso8601_basic_short }}.alloy"
```

**Benefits:**
1. Non-destructive - writes to /tmp
2. Shows diff vs production config
3. Runs validation before deployment
4. Leaves test artifact for manual inspection
5. Can be run repeatedly during development

**Usage pattern:**
```bash
# Development cycle
edit templates → run test → check validation → iterate
# When passing
run test → review diff → deploy production
```

### 5. Alloy Metrics Endpoint Usage

**Built-in metrics at http://127.0.0.1:12345/metrics:**
- `alloy_build_info` - Version tracking
- `alloy_component_controller_running_components` - Component health
- `loki_process_dropped_lines_total` - Processing stats
- `loki_write_sent_entries_total` - Forward success rate

**Use cases:**
- Monitor the monitoring system itself
- Track log pipeline health
- Alert on component failures
- Dashboard for Alloy operational status

**Security:** Always bind to localhost (127.0.0.1) - Telegraf on same host can scrape without network exposure.

## Files Modified

### Core Implementation
- `solti-monitoring/roles/alloy/templates/classifiers/bind9-journal-classifier.alloy.j2` - Bind9 log classification
- `solti-monitoring/roles/alloy/defaults/main.yml` - Configuration defaults

### Infrastructure (for future)
- `solti-monitoring/roles/telegraf/templates/inputs/prometheus-alloy.conf.j2` - Alloy metrics scraper
- `solti-monitoring/roles/telegraf/tasks/telegrafd-inputs-setup.yml` - Deployment task

### Documentation
- `solti-monitoring/docs/METRICS_COLLECTION_STRATEGY.md` - Architecture decision
- `solti-monitoring/docs/bind9-filter-assessment.md` - Bind9 integration analysis

### Deployment
- `mylab/playbooks/fleur/22-fleur-alloy.yml` - Production deployment
- `mylab/playbooks/fleur/91-fleur-alloy-test.yml` - Test validation

## Next Steps / Recommendations

### Immediate (Next Sprint)
1. **Verify Bind9 logs in Loki** - Confirm classifications are correct
2. **Build Grafana dashboard** - Visualize Bind9 events from Loki
3. **Add alerting** - Security events (denied queries, DNSSEC failures)

### Future Enhancements
1. **DNS Performance Metrics** - Deploy Telegraf with `inputs.bind` plugin
2. **Alloy Operational Dashboard** - Use Telegraf to scrape Alloy metrics endpoint
3. **Additional Service Classifiers** - Apply same pattern to other journald services
4. **Filter Tuning** - Monitor what's being dropped, adjust as needed

## Lessons for Future Development

### Do
- ✅ Use test playbooks for non-destructive validation
- ✅ Run `alloy run` manually to see full runtime errors
- ✅ Keep opt-in features disabled by default
- ✅ Document architecture decisions when abandoning approaches
- ✅ Preserve infrastructure for future use (Telegraf scraper)

### Don't
- ❌ Trust validation alone - runtime errors can still occur
- ❌ Mix security (logs) and performance (metrics) pipelines
- ❌ Parse logs for metrics when native plugin exists
- ❌ Deploy to production without testing in /tmp first

## References
- Alloy documentation: https://grafana.com/docs/alloy/latest/
- LogQL selectors: https://grafana.com/docs/loki/latest/query/
- Telegraf Bind plugin: https://github.com/influxdata/telegraf/tree/master/plugins/inputs/bind

## Sprint Metrics
- **Time invested:** ~3 hours (exploration, debugging, documentation)
- **Commits:** 4 checkpoint commits + 1 final
- **Lines changed:** ~500 (template, docs, infrastructure)
- **Production impact:** Zero downtime, Alloy stable throughout
- **Knowledge gained:** Architecture clarity, debugging workflow, test patterns
