---
title: Getting started
seo_title: "Getting Started: Android, iOS & KMP Setup"
description: Install PrintBeam, set up platform permissions, and print your first receipt from an Android, iOS, or Kotlin Multiplatform app.
---

# Getting started

This guide takes you from an empty project to a printed receipt. Pick your platform
below; each tab is complete on its own. The [API guide](API.md) explains every method
in depth once you're running.

<div class="tabs" data-tabs>
<div class="tab" data-title="Android" markdown="1">

## 1. Install

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

Requires minSdk 26. No credentials needed.

## 2. Permissions

The library's manifest already declares everything manifest-level (`INTERNET`,
`ACCESS_NETWORK_STATE`, the Bluetooth set), so your `AndroidManifest.xml` needs no
changes. **Apps printing only to network printers are done: skip to step 3.**

For BLE printers, your app must request the runtime permissions.
`BluetoothPermissions` returns the right set per Android version:

```kotlin
class MainActivity : ComponentActivity() {

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) {
        // Re-fires any in-flight scan without the user tapping Rescan.
        BluetoothPermissions.notifyChanged()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!BluetoothPermissions.allGranted(this)) {
            permissionLauncher.launch(BluetoothPermissions.required())
        }
    }
}
```

| Android version | What gets requested |
|---|---|
| 12+ (API 31+) | `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`. The prompt reads "Find nearby devices", not location. |
| 11 and below | `ACCESS_FINE_LOCATION`. An Android quirk: BLE scans return nothing without it, even though the library derives no location. |

> If your app has a strict `network_security_config.xml`: thermal printers speak plain
> TCP with no TLS, so allowlist the printer subnet with
> `cleartextTrafficPermitted="true"`.

## 3. Initialize

Call `PrintBeam.initialize` once per process, before any other `PrintBeam` call.
`Application.onCreate` is the natural home:

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        PrintBeam.initialize(PrintBeamConfig(context = PrinterContext(this)))
    }
}
```

Pass the **application** context, never an Activity: the library holds the reference
for its lifetime. If you initialize from an Activity instead, guard against
re-running on configuration changes; a second call replaces the facade and throws if
a printer is connected at that moment.

## 4. Find printers

Results stream in as printers respond, so populate your list live instead of waiting
for the end:

```kotlin
val handle = PrintBeam.scan(
    transports = setOf(Transport.NETWORK, Transport.BLE),
    listener = object : ScanListener {
        override fun onPrinterFound(printer: DiscoveredPrinter) {
            // Key your list by printer.id: a later source can re-emit the same
            // printer with a resolved name. Replace the row, don't append.
            printers = printers.filterNot { it.id == printer.id } + printer
        }
        override fun onTransportFailed(transport: Transport, cause: PrinterException) {
            // One source failed (e.g. BLE permission denied). Others keep scanning.
        }
        override fun onFinished(found: List<DiscoveredPrinter>) {
            printers = found
        }
    },
)
// handle.cancel() when your picker UI is dismissed.
```

Every found printer is registered automatically; its `id` works with `print`
immediately. For an "enter IP address" fallback:

```kotlin
val id = PrintBeam.addManualPrinter(PrinterEndpoint.Network("192.168.1.50", 9100))
```

## 5. Print

```kotlin
lifecycleScope.launch {
    val result = PrintBeam.print(printerId) {
        align(Alignment.CENTER)
        bold { text("MY STORE") }
        align(Alignment.LEFT)
        line("Coffee", "$3.50")
        divider("-")
        line("Total", "$3.50")
        qrCode("https://store.example/r/12345")
        cut()
    }
    if (result is PrintResult.Failure) {
        // Transport problems land here, never as exceptions.
        show(result.exception)
    }
}
```

`print` auto-connects and holds the connection for the next receipt. On BLE that
skips a 1-to-3-second handshake per print. If the link died between prints, the SDK
reopens it once automatically.

## Next steps

- Complete working app: [freshcart-android](https://github.com/kotimadduluri/printbeam-samples/tree/main/freshcart-android)
- Every method in depth: [API guide](API.md)
- Something not working: [Troubleshooting](TROUBLESHOOTING.md)

</div>
<div class="tab" data-title="iOS (Swift)" markdown="1">

## 1. Install

In Xcode: **File → Add Package Dependencies**, then enter this repository's URL and
pin the exact version:

```
https://github.com/kotimadduluri/printbeam-sdk
```

The package serves a prebuilt XCFramework (arm64 device and arm64 simulator).
Requires iOS 13+. Then `import PrintBeam` wherever you use it.

## 2. Info.plist

Add these keys to your app target. **This step is not optional**: without them,
discovery fails silently with no error anywhere.

```xml
<!-- Network printer discovery (Bonjour) -->
<key>NSLocalNetworkUsageDescription</key>
<string>Discovers and prints to printers on your local network.</string>
<key>NSBonjourServices</key>
<array>
    <string>_pdl-datastream._tcp</string>
    <string>_printer._tcp</string>
    <string>_ipp._tcp</string>
</array>

<!-- BLE printer discovery + connection -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Discovers and prints to nearby Bluetooth thermal printers.</string>
```

> Missing `NSBluetoothAlwaysUsageDescription` puts CoreBluetooth in the
> `unauthorized` state with no prompt and empty scans. A service type missing from
> `NSBonjourServices` makes the mDNS browse callback simply never fire on iOS 14+.
> Don't add the deprecated `NSBluetoothPeripheralUsageDescription`.

## 3. Initialize

Once, at the app root. Kotlin default arguments don't carry across the Swift bridge,
so spell out every config parameter:

```swift
import PrintBeam

@main
struct MyApp: App {
    init() {
        let logger = PrinterLoggerCompanion.shared.NoOp
        let config = PrintBeamConfig(
            context: PrinterContext(externalCentralManager: nil),
            logger: logger,
            connectionFactory: DefaultConnectionFactory(logger: logger),
            defaultPaperWidth: PaperWidth.mm80
        )
        try? PrintBeam.shared.initialize(config: config)
    }
    // ...
}
```

Passing `nil` for the central manager lets the library lazily build one when BLE is
first used; network printing works without it. If your app already manages its own
`CBCentralManager`, pass it in instead. Construct `PrinterContext` exactly once:
scan and connect must share one central manager or iOS BLE silently breaks.

## 4. Find printers

Kotlin interfaces surface as Obj-C protocols, so the listener inherits `NSObject`.
All callbacks arrive on the main thread; touching view state directly is safe:

```swift
final class PrinterScanner: NSObject, ScanListener {
    var onUpdate: (([DiscoveredPrinter]) -> Void)?
    private var handle: ScanHandle?
    private var byId: [String: DiscoveredPrinter] = [:]

    func start() {
        handle = try? PrintBeam.shared.scan(
            transports: [Transport.network, Transport.ble],
            timeoutMs: 12000,
            listener: self
        )
    }

    func cancel() { handle?.cancel() }

    func onPrinterFound(printer: DiscoveredPrinter) {
        // Keyed by id: a later source can re-emit the same printer with a
        // resolved name. Replace the entry, don't append.
        byId[printer.id] = printer
        onUpdate?(Array(byId.values))
    }
    func onTransportFailed(transport: Transport, cause: PrinterException) {
        // One source failed (e.g. Bluetooth off). Others keep scanning.
    }
    func onFinished(printers: [DiscoveredPrinter]) {
        onUpdate?(printers)
    }
}
```

For an "enter IP address" fallback:

```swift
let id = try PrintBeam.shared.addManualPrinter(
    endpoint: PrinterEndpoint.Network(host: "192.168.1.50", port: 9100),
    name: nil,
    paperWidth: nil
)
```

## 5. Print

Every suspending Kotlin function is `async` in Swift:

```swift
let result = try await PrintBeam.shared.print(printerId: printerId, block: { builder in
    builder.align(alignment: Alignment.center)
    builder.bold { _ in
        builder.text(value: "MY STORE")
    }
    builder.align(alignment: Alignment.left)
    builder.line(left: "Coffee", right: "$3.50")
    builder.divider(char: "-")
    builder.line(left: "Total", right: "$3.50")
    builder.qrCode(data: "https://store.example/r/12345", moduleSize: 6, errorCorrection: 49)
    builder.cut(partial: false)
})
if let failure = result as? PrintResult.Failure {
    // Transport problems land here, never as thrown errors.
    show(failure.exception)
}
```

`print` auto-connects and holds the connection for the next receipt. On BLE that
skips a 1-to-3-second handshake per print. Match sealed classes with casts
(`as? PrintResult.Failure`, `as? PrinterState.Connected`): bridged Kotlin subtype
checks work through casting, not `switch`.

## Next steps

- Complete working app: [freshcart-ios](https://github.com/kotimadduluri/printbeam-samples/tree/main/freshcart-ios)
- Every method in depth: [API guide](API.md)
- Something not working: [Troubleshooting](TROUBLESHOOTING.md)

</div>
<div class="tab" data-title="KMP + Compose" markdown="1">

## 1. Install

One dependency in `commonMain`; Gradle resolves the right artifact per target:

```kotlin
// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven("https://kotimadduluri.github.io/printbeam-sdk/maven")
    }
}

// your KMP module's build.gradle.kts
kotlin {
    sourceSets {
        commonMain.dependencies {
            implementation("dev.printbeam:printbeam:0.1.0-alpha04")
        }
    }
}
```

Use Kotlin 2.3 or newer. **Do not** also depend on `printbeam-android` from
`androidMain`: that disables variant resolution and breaks the iOS build. The single
`commonMain` line already gives `androidMain` the platform helpers like
`BluetoothPermissions`.

## 2. Platform setup

Both platform shells need their native setup even though your printing code is shared:

- **Android**: request BLE runtime permissions from your Activity, then call
  `BluetoothPermissions.notifyChanged()` in the result callback so an in-flight scan
  re-fires. Network-only apps skip this. The exact snippet is in this guide's
  **Android** tab, step 2.
- **iOS**: add `NSLocalNetworkUsageDescription`, `NSBonjourServices`, and
  `NSBluetoothAlwaysUsageDescription` to the Xcode target's Info.plist. Without them,
  discovery fails silently. The exact keys are in the **iOS (Swift)** tab, step 2.

## 3. Initialize

Each platform entry point makes exactly one call. Shared code never sees a `Context`
or `CBCentralManager`.

```kotlin
// androidApp: once per process. Application.onCreate needs no guard.
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        PrintBeam.initialize(PrintBeamConfig(context = PrinterContext(this)))
    }
}
```

```kotlin
// iosMain: the ComposeUIViewController factory runs once per process,
// making it the iOS twin of Application.onCreate.
fun MainViewController() = run {
    PrintBeam.initialize(PrintBeamConfig(context = PrinterContext()))
    ComposeUIViewController { App() }
}
```

## 4. Scan and print from shared code

Everything below lives in `commonMain`. Callbacks arrive on the main dispatcher, so
they can touch Compose state directly:

```kotlin
class PrinterViewModel : ViewModel() {
    var printers by mutableStateOf(emptyList<DiscoveredPrinter>())
        private set
    private var scanHandle: ScanHandle? = null

    fun startScan() {
        scanHandle = PrintBeam.scan(
            transports = setOf(Transport.NETWORK, Transport.BLE),
            listener = object : ScanListener {
                override fun onPrinterFound(printer: DiscoveredPrinter) {
                    // Key by id: a later source can re-emit the same printer
                    // with a resolved name. Replace the row, don't append.
                    printers = printers.filterNot { it.id == printer.id } + printer
                }
                override fun onTransportFailed(transport: Transport, cause: PrinterException) {
                    // One source failed. The others keep scanning.
                }
                override fun onFinished(found: List<DiscoveredPrinter>) {
                    printers = found
                }
            },
        )
    }

    fun print(printer: DiscoveredPrinter) {
        viewModelScope.launch {
            val result = PrintBeam.print(printer.id) {
                align(Alignment.CENTER); bold { text("MY STORE") }
                line("Coffee", "$3.50")
                divider("-")
                line("Total", "$3.50")
                cut()
            }
            // PrintResult.Success or PrintResult.Failure. Transport errors never throw.
        }
    }

    override fun onCleared() {
        scanHandle?.cancel()
    }
}
```

`print` auto-connects and holds the connection for the next receipt. On BLE that
skips a 1-to-3-second handshake per print. If the link died between prints, the SDK
reopens it once automatically.

## Next steps

- Complete working app: [freshcart-kmp](https://github.com/kotimadduluri/printbeam-samples/tree/main/freshcart-kmp)
- Every method in depth: [API guide](API.md)
- Something not working: [Troubleshooting](TROUBLESHOOTING.md)

</div>
</div>
