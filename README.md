# PrintLib SDK

**ESC/POS thermal printing for Android, iOS, and Kotlin Multiplatform — one API for network
(Wi-Fi / Ethernet) and Bluetooth Low Energy printers.**

This repository is the official binary distribution of PrintLib: a hosted Maven repository,
a Swift Package, per-release XCFrameworks, and the API documentation. The SDK is **free to
use, including commercially** — see [LICENSE.md](LICENSE.md). Source code is not distributed.

[![Latest release](https://img.shields.io/github/v/release/kotimadduluri/printlib-sdk?include_prereleases&label=version)](https://github.com/kotimadduluri/printlib-sdk/releases)
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
        maven("https://kotimadduluri.github.io/printlib-sdk/maven")
    }
}

// build.gradle.kts
dependencies {
    implementation("io.github.kotimadduluri:printlib-android:0.1.0-alpha01")
}
```

### Kotlin Multiplatform (Android + iOS from one codebase)

Same repository line as above, then in `commonMain`:

```kotlin
dependencies {
    implementation("io.github.kotimadduluri:printlib:0.1.0-alpha01")
}
```

### iOS app (Swift)

Xcode → File → **Add Package Dependencies** → enter this repository's URL:

```
https://github.com/kotimadduluri/printlib-sdk
```

and pin the exact version. The package serves a prebuilt XCFramework (arm64 device +
arm64 simulator).

No credentials or accounts are needed for any of the above.

---

## 60-second tour

```kotlin
// Once, at app startup:
PrintLib.initialize(PrintLibConfig(context = PrinterContext(applicationContext)))

// Find printers — results stream in as they respond, Wi-Fi and BLE alike:
PrintLib.scan(transports = setOf(Transport.NETWORK, Transport.BLE), listener = myListener)

// Print by stable id — PrintLib holds the connection across prints and
// reopens dead links automatically:
PrintLib.print(printerId) {
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

- **[API reference](https://kotimadduluri.github.io/printlib-sdk/api/)** — full Dokka docs
  for the public surface.
- **Sample apps** — three complete integrations (native Android, native Swift, Kotlin
  Multiplatform): *coming with the first release.*
- **[Releases](https://github.com/kotimadduluri/printlib-sdk/releases)** — changelogs and
  XCFramework downloads.

## Support

Questions and bug reports → [Issues](https://github.com/kotimadduluri/printlib-sdk/issues).
