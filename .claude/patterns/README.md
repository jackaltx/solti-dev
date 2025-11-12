# SOLTI Implementation Patterns

**READ THIS FIRST** before implementing any new role in SOLTI collections.

## Purpose

This directory contains **mandatory implementation patterns** used across all SOLTI collections. These patterns ensure consistency, maintainability, and visual clarity in the codebase.

## Available Patterns

| Pattern | File | Status | Used In |
|---------|------|--------|---------|
| **SOLTI Ecosystem** | [solti-ecosystem.md](solti-ecosystem.md) | READ FIRST | Organization |
| **State Management** | [state-management.md](state-management.md) | Mandatory | All roles |
| **Role Structure** | [role-structure.md](role-structure.md) | Mandatory | All roles |

## Quick Start

### Understanding the Ecosystem (First Time)

1. **Understand the organization**:
   - [solti-ecosystem.md](solti-ecosystem.md) - How jackaltx coordinates collections
   - Each collection is an independent GitHub repo
   - Patterns are shared across all collections

### Creating a New Role

1. **Read the patterns**:
   - [state-management.md](state-management.md) - How roles manage state
   - [role-structure.md](role-structure.md) - Directory layout and files

2. **Study reference implementations**:
   - Primary: `solti-containers/roles/influxdb3/tasks/main.yml`
   - Also see: redis, elasticsearch, hashivault

3. **Copy the annotated example**:
   - See: [examples/influxdb3-annotated.yml](examples/influxdb3-annotated.yml)

4. **Verify understanding**:
   - Before writing code, describe the pattern you're following
   - Confirm state flow matches the pattern

## Philosophy

### Why These Patterns Matter

**Visual Clarity**: State-based blocks with section markers make the flow obvious at a glance. No mental parsing required.

**Consistency**: All roles work the same way. Learn one, understand all.

**Maintainability**: Changes are localized to state blocks. Easy to debug.

**Testability**: Each state can be tested independently.

## Pattern Violations

If you find code that doesn't follow these patterns:
1. Note it as technical debt
2. Refactor when touching that code
3. Don't replicate the anti-pattern

## For AI Assistants (Claude Code)

When implementing a new role:

1. **STOP** - Don't write code yet
2. **READ** the pattern documents in this directory
3. **STUDY** the reference implementations
4. **DESCRIBE** the pattern you'll follow
5. **GET APPROVAL** before writing code
6. **IMPLEMENT** following the approved pattern

## Pattern Evolution

These patterns are based on lessons learned from:
- solti-containers (influxdb3, redis, elasticsearch, hashivault)
- solti-monitoring (telegraf, alloy, loki)
- solti-ensemble (mariadb, fail2ban)

As we learn better approaches, patterns will evolve. Changes will be documented with rationale.

## Questions?

Ask before implementing. Better to clarify the pattern than fix code later.
