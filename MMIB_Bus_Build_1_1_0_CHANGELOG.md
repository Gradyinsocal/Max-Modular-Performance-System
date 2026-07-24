# MMPS Changelog

## Milestone 2 — The Bus Awakens

### MMIB 1.1.0 — Event Routing Unit Test

Added:

- Standard event input:
  `EVENT|Source Module|Event Name`
- Standard routed event:
  `ROUTE|Event Name|Source Module`
- Standard acknowledgment:
  `ACK|Event Name|Source Module|OK`
- Bus-ready protection.
- Isolated SYS and STOP routing test.
- Exact route and acknowledgment counting.

Preserved:

- Duplicate-safe registration.
- Required and optional module registry.
- One-time startup report.
- Silent production mode.

Not yet included:

- Production console integration.
- Performance Manager integration.
- State ownership.
- Health monitoring.
