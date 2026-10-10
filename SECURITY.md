# Security policy

Swift-JSON processes untrusted bytes and schemas using strict grammar, checked
finite growth/work limits and cancellation within owned loops. Local native
qualification does not assert independent security certification.

## Reporting a vulnerability

Use the repository's **private vulnerability reporting** feature:
[Security → Report a vulnerability](https://github.com/ThorFuchs/Swift-JSON/security).
Maintainer: [Thorsten Fuchs (@ThorFuchs)](https://github.com/ThorFuchs).
Do not open a public issue containing an exploit or private payload.

Include a minimal reproducer, expected and observed behavior, affected commit or
version, macOS/Swift/SDK versions, resource profile and reproduction command.
Redact credentials and application data. Reports receive best-effort review;
no response-time or remediation SLA is promised.

## Supported versions

Once the first stable release exists, security and defect fixes target the latest
published **1.x** release. Older patch/minor versions should upgrade to that release.
No backport or extended-support commitment is made for older release lines.
Before 1.0.0 is released, the current `main` candidate receives best-effort fixes;
there is no published stable version yet. See [SUPPORT.md](SUPPORT.md).

## Boundaries

Limits bound documented logical ownership and charged work; they do not enforce
an OS RSS ceiling or bound caller callbacks. Callers own transport security,
authorization, process isolation and atomic acceptance of provisional stream
records. Schemas do not trigger automatic network access. See the
[resource contract](Documentation/Architecture/ResourceLimits.md).
