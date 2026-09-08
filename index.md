---
title: PrintBeam
description: ESC/POS thermal printing for Android, iOS, and Kotlin Multiplatform. One API for network and BLE printers.
---

# ESC/POS receipt printing, one API

PrintBeam prints to network and Bluetooth LE thermal printers from Android, iOS, and
Kotlin Multiplatform apps. Free to use, including commercially.

## Install

<div class="tabs" data-tabs markdown="1">
<div class="tab" data-title="Android" markdown="1">
Add the repository and the dependency:

```kotlin
// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven("https://kotimadduluri.github.io/printbeam-sdk/maven")
    }
}

// app/build.gradle.kts
dependencies {
    implementation("dev.printbeam:printbeam-android:0.1.0-alpha04")
}
```

Requires minSdk 26. No credentials or accounts are needed.
</div>
<div class="tab" data-title="iOS (Swift)" markdown="1">
In Xcode: **File → Add Package Dependencies** and enter this repository's URL:

```
https://github.com/kotimadduluri/printbeam-sdk
```

Pin the exact version. The package serves a prebuilt XCFramework (arm64 device and
arm64 simulator). Requires iOS 13+.
</div>
<div class="tab" data-title="KMP + Compose" markdown="1">
Add the repository (same as Android), then one dependency in `commonMain`:

```kotlin
kotlin {
    sourceSets {
        commonMain.dependencies {
            implementation("dev.printbeam:printbeam:0.1.0-alpha04")
        }
    }
}
```

Gradle resolves the right artifact per target. Use Kotlin 2.3 or newer. Do not also
depend on `printbeam-android` from `androidMain`: that disables variant resolution and
breaks the iOS build.
</div>
</div>

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

## Documentation

<div class="doc-grid">
  <a href="{{ '/docs/GETTING-STARTED.html' | relative_url }}">
    <span class="doc-title">Getting started</span>
    <span class="doc-sub">Install, permissions, and your first receipt, per platform.</span>
  </a>
  <a href="{{ '/docs/API.html' | relative_url }}">
    <span class="doc-title">API guide</span>
    <span class="doc-sub">Every public method explained, with usage patterns.</span>
  </a>
  <a href="{{ '/api/' | relative_url }}">
    <span class="doc-title">API reference</span>
    <span class="doc-sub">Generated docs for every public symbol.</span>
  </a>
  <a href="{{ '/docs/COMPATIBILITY.html' | relative_url }}">
    <span class="doc-title">Compatibility</span>
    <span class="doc-sub">Which printers are confirmed, and which toolchain versions.</span>
  </a>
  <a href="{{ '/docs/TROUBLESHOOTING.html' | relative_url }}">
    <span class="doc-title">Troubleshooting</span>
    <span class="doc-sub">Scans that find nothing, BLE quirks, wrong characters.</span>
  </a>
  <a href="https://github.com/kotimadduluri/printbeam-samples">
    <span class="doc-title">Sample apps</span>
    <span class="doc-sub">The same grocery app, three ways: Android, iOS, and KMP.</span>
  </a>
  <a href="https://github.com/kotimadduluri/printbeam-sdk/releases">
    <span class="doc-title">Releases</span>
    <span class="doc-sub">Changelogs and XCFramework downloads.</span>
  </a>
</div>

## Support

Questions and bug reports go to
[Issues](https://github.com/kotimadduluri/printbeam-sdk/issues). The SDK is
distributed as binaries; see the
[license](https://github.com/kotimadduluri/printbeam-sdk/blob/main/LICENSE.md) for terms.
