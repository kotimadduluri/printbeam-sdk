# PrintBeam SDK

**ESC/POS thermal printing for Android, iOS, and Kotlin Multiplatform — one API for network
(Wi-Fi / Ethernet) and Bluetooth Low Energy printers.**

This repository is the official binary distribution of PrintBeam: a hosted Maven repository,
a Swift Package, per-release XCFrameworks, and the API documentation. The SDK is **free to
use, including commercially** — see [LICENSE.md](LICENSE.md). Source code is not distributed.

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
    implementation("dev.printbeam:printbeam-android:0.1.0-alpha03")
}
```

### Kotlin Multiplatform (Android + iOS from one codebase)

Same repository line as above, then in `commonMain`:

```kotlin
dependencies {
    implementation("dev.printbeam:printbeam:0.1.0-alpha03")
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

// Find printers — results stream in as they respond, Wi-Fi and BLE alike:
PrintBeam.scan(transports = setOf(Transport.NETWORK, Transport.BLE), listener = myListener)

// Print by stable id — PrintBeam holds the connection across prints and
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

Every suspend function has a callback twin for Swift and Java call sites; per-printer
connection state is observable as a `Flow<PrinterState>`.

---

## Documentation

- **[API guide](docs/API.md)** — every public method explained, with the patterns they're
  meant to be used in.
- **[API reference](https://kotimadduluri.github.io/printbeam-sdk/api/)** — full Dokka docs
  for the public surface.
- **[Sample apps](https://github.com/kotimadduluri/printbeam-samples)** — three complete
  integrations of the same grocery app: native Android (Compose), native iOS (SwiftUI),
  and Kotlin Multiplatform.
- **[Releases](https://github.com/kotimadduluri/printbeam-sdk/releases)** — changelogs and
  XCFramework downloads.

## Support

Questions and bug reports → [Issues](https://github.com/kotimadduluri/printbeam-sdk/issues).
