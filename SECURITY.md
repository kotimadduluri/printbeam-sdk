# Security policy

PrintBeam opens network sockets and Bluetooth connections inside other people's apps, often
in payment and point-of-sale software. Security reports are taken seriously.

## Supported versions

Only the latest published release receives fixes. The SDK is pre-1.0, so there are no
long-term support branches. The current version is listed on the
[releases page](https://github.com/kotimadduluri/printbeam-sdk/releases).

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

Use GitHub's private reporting instead:
[Report a vulnerability](https://github.com/kotimadduluri/printbeam-sdk/security/advisories/new).
It creates a private thread visible only to you and the maintainer.

If that form is unavailable, email **kotimn@gmail.com** with "PrintBeam security" in the
subject line.

Useful things to include, as far as you have them:

- Which version and platform.
- What an attacker can do, and what access they need to do it.
- Steps to reproduce, or a proof of concept.
- Whether a printer or a network position is required.

## What to expect

This is a single-maintainer project, so response times are best effort rather than a
contractual commitment:

| Stage | Target |
|---|---|
| Acknowledgement | Within 5 working days |
| Initial assessment | Within 10 working days |
| Fix or documented mitigation | Depends on severity, discussed with you on the thread |

Reports are credited in the release notes unless you ask otherwise. There is no bug bounty.

## Scope

In scope: anything in the published SDK artifacts, the release pipeline that produces them,
and the hosted Maven repository that serves them.

Out of scope, because they are inherent to the protocol rather than defects:

- **ESC/POS traffic is unencrypted.** Thermal printers speak plain TCP on port 9100 with no
  TLS, and BLE printers rarely implement pairing. Anyone on the same network segment can read
  or inject print traffic. Treat the printer link as untrusted, and do not print secrets you
  would not put on paper anyway.
- **The subnet scan probes the local /24.** That is the documented behaviour of network
  discovery, and it can be turned off with `NetworkScanOptions(enablePortScan = false)`.
- Vulnerabilities in an app that consumes the SDK, unless the SDK caused them.
