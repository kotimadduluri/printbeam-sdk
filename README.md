<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark.svg">
    <img src="assets/logo-light.svg" alt="PrintBeam" height="76">
  </picture>
</p>

**ESC/POS thermal printing for Android, iOS, and Kotlin Multiplatform. One API for network
and BLE printers.**

This repository is the official binary distribution of PrintBeam: a hosted Maven repository,
a Swift Package, per-release XCFrameworks, and the API documentation. The SDK is **free to
use, including commercially** — see [LICENSE.md](https://github.com/kotimadduluri/printbeam-sdk/blob/main/LICENSE.md).
Source code is not distributed.

**Docs live at [kotimadduluri.github.io/printbeam-sdk](https://kotimadduluri.github.io/printbeam-sdk/).**

[![Latest release](https://img.shields.io/github/v/release/kotimadduluri/printbeam-sdk?include_prereleases&label=version)](https://github.com/kotimadduluri/printbeam-sdk/releases)
[![Platforms](https://img.shields.io/badge/platforms-Android%2026%2B%20·%20iOS%2013%2B-blue)]()

---

## Install

### Android app (Kotlin/Java)

```kotlin
// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven("https://kotimadduluri.github.io/printbeam-sdk/maven")
    }
}

// build.gradle.kts
dependencies {
    implementation("dev.printbeam:printbeam-android:0.1.0-alpha04")
}
```

### Kotlin Multiplatform (Android + iOS from one codebase)

Same repository line as above, then in `commonMain`:

```kotlin
dependencies {
    implementation("dev.printbeam:printbeam:0.1.0-alpha04")
}
```

### iOS app (Swift)

Xcode → File → **Add Package Dependencies** → enter this repository's URL:

```
https://github.com/kotimadduluri/printbeam-sdk
```

and pin the exact version. The package serves a prebuilt XCFramework (arm64 device +
arm64 simulator).

No credentials or accounts are needed for any of the above.

---

## 60-second tour

```kotlin
// Once, at app startup:
PrintBeam.initialize(PrintBeamConfig(context = PrinterContext(applicationContext)))

// Find printers. Results stream in as they respond, network and BLE alike:
PrintBeam.scan(transports = setOf(Transport.NETWORK, Transport.BLE), listener = myListener)

// Print by stable id. PrintBeam holds the connection across prints and
// reopens dead links automatically:
PrintBeam.print(printerId) {
    align(Alignment.CENTER); bold { text("MY STORE") }
    line("Coffee", "$3.50")
    divider("-")
    line("Total", "$3.50")
    qrCode("https://store.example/r/12345")
    cut()
}
```

Every suspend function has a callback twin for Swift and Java call sites. Per-printer
connection state is observable as a `Flow<PrinterState>`.

---

## Documentation

- **[Getting started](docs/GETTING-STARTED.md)** — install, permissions, and your first
  receipt, with a tab per platform (Android, iOS, KMP + Compose).
- **[API guide](docs/API.md)** — every public method explained, with the patterns to use
  them in.
- **[Compatibility](docs/COMPATIBILITY.md)** — confirmed printers, and which Kotlin, AGP and
  platform versions each release supports.
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** — empty scans, BLE quirks, wrong
  characters, permission problems.
- **[API reference](https://kotimadduluri.github.io/printbeam-sdk/api/)** — full Dokka docs
  for the public surface.
- **[Sample apps](https://github.com/kotimadduluri/printbeam-samples)** — three complete
  integrations of the same grocery app: native Android (Compose), native iOS (SwiftUI),
  and Kotlin Multiplatform.
- **[Releases](https://github.com/kotimadduluri/printbeam-sdk/releases)** — changelogs and
  XCFramework downloads.

## Where this is going

PrintBeam is pre-1.0 and maintained by one person, so here is the honest state of it rather
than a roadmap with dates on it.

**Working on now.** Widening hardware coverage. The SDK is tested on the two printers its
author owns, which is the weakest part of the project. Every
[compatibility report](https://github.com/kotimadduluri/printbeam-sdk/issues/new?template=printer_report.yml)
directly improves it, including reports that a printer works.

**Likely next**, roughly in order: lifecycle-aware sessions for battery-powered handhelds
(see the note on held sessions in the [API guide](docs/API.md#sessions)), a USB transport for
countertop terminals, and a JVM desktop target. None of these are started, and real requests
will reorder them.

**Deliberately out of scope.** Bluetooth Classic and SPP. iOS restricts Bluetooth Classic to
MFi-certified accessories and generic thermal printers are not certified, so supporting it
would mean the API stops being the same on both platforms. Network plus BLE covers modern
hardware. The `ConnectionFactory` seam is public if you want to add a transport yourself.

**What 1.0 means here.** A public API that stops changing between releases, a meaningfully
wider set of confirmed printers, and a deprecation policy. Until then, expect the API to move
between alpha versions, and pin an exact version.

## Support

Questions and bug reports → [Issues](https://github.com/kotimadduluri/printbeam-sdk/issues).
