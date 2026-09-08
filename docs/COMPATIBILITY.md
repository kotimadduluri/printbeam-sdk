---
title: Compatibility
seo_title: "Supported Printers & Toolchain Versions"
description: Which thermal printers PrintBeam has been tested with, and which Kotlin, AGP, Android and iOS versions each release supports.
---

# Compatibility

Two separate questions: will it build in your project, and will it drive your printer.

## Toolchain

| PrintBeam | Kotlin | AGP | Android | iOS | Coroutines |
|---|---|---|---|---|---|
| 0.1.0-alpha04 | 2.3.x | 9.x | minSdk 26 | 13+ | 1.10.x |

Notes that save an afternoon:

- **Kotlin version matters for KMP consumers.** The published klibs are built with Kotlin
  2.3.x. Kotlin's klib format is not forward compatible, so a project on an older Kotlin
  cannot read them and fails with a metadata or klib version error that names PrintBeam rather
  than the real cause. If you see that, check your Kotlin version before anything else.
- **Android-only consumers are unaffected by the above.** The AAR is ordinary bytecode, so
  `dev.printbeam:printbeam-android` works on older Kotlin versions.
- **Coroutines is an `api` dependency**, not `implementation`, because `Flow` and suspend
  types appear in the public surface. You do not need to declare it yourself, and you should
  not pin an older version alongside it.
- **iOS consumers get a prebuilt XCFramework** (arm64 device and arm64 simulator), so the
  Kotlin version is irrelevant there. Intel simulator slices are not published.

## Printers

Thermal printers vary enormously in how faithfully they implement ESC/POS, so this list is the
honest state of what has been confirmed rather than a claim about the whole category.

**Only two printers have been tested, both by the author.** That is the weakest part of the
project, and it is the one thing the community can fix. If you try PrintBeam with any printer,
[tell us what happened](https://github.com/kotimadduluri/printbeam-sdk/issues/new?template=printer_report.yml).
Reports that a printer **works** are just as valuable as reports that it does not.

### Confirmed

| Printer | Transport | Status | Notes |
|---|---|---|---|
| EPSON TM-m30 | Network | Works | Discovered by mDNS and by subnet scan. Returns its identity to `GS I`, so it appears named in scan results. |
| GoodCom RPP02N class | Bluetooth LE | Works | Cheap 58mm BLE hardware. Needs the write pacing the SDK applies by default. Ignores `GS I`, so it appears unnamed. |

### Expected to work, not yet confirmed

These are covered by the built-in `BleProfile` presets or by standard ESC/POS network
behaviour, but nobody has reported back on them. Treat as untested.

| Printer family | Transport | Basis |
|---|---|---|
| Star Micronics TSP143 series | Network | Standard ESC/POS over TCP 9100. |
| Star Micronics SM-L200 class | Bluetooth LE | Covered by `BleProfile.STAR_BLE`. |
| Bixolon SPP-R200III | Bluetooth LE | Nordic UART profile, the SDK default. |
| Xprinter XP-P323B and similar | Bluetooth LE | Nordic UART or the 0xFF00 generic profile. |
| Generic no-name 58mm BLE printers | Bluetooth LE | Covered by `BleProfile.GENERIC_ESCPOS` plus characteristic auto-detection. |

### Known not to work

| Printer | Why |
|---|---|
| Star TSP100IIIBI | Uses Star's MFi accessory protocol over Bluetooth Classic. Not ESC/POS over BLE, and out of scope. |
| Any Bluetooth Classic / SPP-only printer | iOS restricts Bluetooth Classic to MFi-certified accessories and generic thermal printers are not certified, so supporting it on Android alone would break the single-API promise. See the [troubleshooting page](TROUBLESHOOTING.md). |

## If your printer is not listed

Try it anyway. Most ESC/POS hardware works without any configuration, because network printers
follow the protocol closely and BLE printers are handled by characteristic auto-detection.
[Troubleshooting](TROUBLESHOOTING.md) covers what to do when a printer connects but prints
nothing, garbles output, or truncates long receipts. Then please report the result either way.
