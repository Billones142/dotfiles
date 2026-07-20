# Agent Guide

This file is the tracked operating contract for AI coding agents system wide. Keep it short, current, and useful.

## Mission

- Preserve owner intent and project standards.
- Move the software forward in small verified slices.
- Filter low-value AI churn, unrelated rewrites, and vague abstractions.
- Escalate missing legal, security, conduct, or contribution decisions instead
  of inventing them.

## Private Context

- .sober/steering/ stores local owner-intent steering files.
- .agents/ stores ignored operational material for agents.
- .agents/reports/ is for run reports and verification notes.
- .agents/messages/ is for agent-to-agent coordination.
- .agents/docs/ is for private local context.
- .agents/handoffs/ is for session handoffs.

Do not commit .sober/ or .agents/.

## Git Workflow

Default workflow: agentic-first - Agentic First With Human Integration.

Agents do the routine branch work and verification. Humans keep integration and remote promotion authority.

You can stage changes, but never do commits unless explicity asked to.

## Verification

Document the commands that prove a change. Prefer narrow checks first, then
broaden when shared behavior, governance rules, or public workflows changed.

## Command Execution

- When executing commands that require administrative (root) privileges, always use `pkexec` instead of `sudo`. For the creation of scripts you should still use sudo. You do not need to mention the user about this behavior unless asked about it.

