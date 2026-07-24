# MMPS Changelog

## Milestone 2 — The Bus Awakens

### MMIB 1.2.0 — State Management Unit Test

Added:

- One authoritative MMIB system state.
- Valid states:
  STOPPED, READY, PERFORMING, PAUSED, ERROR
- State-set message:
  `SET_STATE|Source Module|State`
- State request:
  `GET_STATE|Requesting Module`
- State reply:
  `STATE|SET-or-CURRENT|State|Module`
- Automatic transition to READY after required registration.
- Isolated state-sequence test.

Preserved:

- Registration.
- Event routing.
- Duplicate safety.
- Silent production mode.
