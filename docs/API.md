# PrintBeam API reference

This page explains every public method of the SDK and how to use them together. The
[generated Dokka reference](https://kotimadduluri.github.io/printbeam-sdk/api/) covers every
symbol exhaustively; this page is the annotated companion.

Current version: **0.1.0-alpha04**. All packages live under `dev.printbeam.*`.

The SDK has two layers. Most apps only need the facade, `dev.printbeam.sdk.PrintBeam`. It holds
one connection per printer across prints and manages scan and connect lifecycles for you. The
lower "L1" layer (`Printer`, `PrinterDiscoveryService`) opens and closes a connection per
operation. It exists for advanced integrations and is documented [at the end](#level-1-api-advanced).

Every suspending facade operation has a callback overload with the same name, for Swift and
Java call sites. Suspend variants are main-safe; I/O runs on the SDK's I/O dispatcher
internally. Callback results and all listener callbacks arrive on the **main dispatcher**, so
you can touch UI state directly.

---

## Contents

- [Initialization](#initialization) — `PrintBeamConfig`, `initialize`, `shutdown`
- [Discovery](#discovery) — `scan`, `ScanListener`, `ScanHandle`, `DiscoveredPrinter`
- [The printer registry](#the-printer-registry) — `addManualPrinter`, `rememberPrinter`, `knownPrinters`, persistence
- [Sessions](#sessions) — `connect`, `disconnect`, `printerState`, `PrinterState`
- [Printing](#printing) — `print`, the receipt DSL, `PrintResult`
- [Queries](#queries) — `queryStatus`, `queryDeviceInfo`
- [Receipt DSL reference](#receipt-dsl-reference) — every `ReceiptBuilder` method
- [Core types](#core-types) — endpoints, paper widths, BLE profiles, code pages, exceptions, logging
- [Level 1 API (advanced)](#level-1-api-advanced) — `Printer`, retry helpers, `PrinterDiscoveryService`, custom transports

---

## Initialization

### `PrintBeamConfig`

Configuration for `PrintBeam.initialize`. Construct it once at app startup.

```kotlin
class PrintBeamConfig(
    context: PrinterContext,
    logger: PrinterLogger = PrinterLogger.NoOp,
    connectionFactory: ConnectionFactory = DefaultConnectionFactory(logger),
    defaultPaperWidth: PaperWidth = PaperWidth.MM_80,
)
```

- **`context`** — the platform handle. On Android, construct it with the application `Context`:
  `PrinterContext(applicationContext)`. On iOS, no argument is needed: `PrinterContext()`.
  Required for BLE and for discovery. The facade shares one instance across both, so iOS
  peripheral identity survives the scan-to-connect handoff.
- **`logger`** — sink for library breadcrumbs: discovery, connection negotiation, transport
  writes. Defaults to `PrinterLogger.NoOp`. The SDK writes nothing to the system log unless
  you supply a sink. See [`PrinterLogger`](#printerlogger).
- **`connectionFactory`** — override only for tests or custom transports. See
  [`ConnectionFactory`](#connectionfactory--printerconnection).
- **`defaultPaperWidth`** — used for printers registered by scanning, and for
  `addManualPrinter` calls that don't specify a width.

### `PrintBeam.initialize(config)`

Installs the configuration and makes the facade operational. Call it once, before any other
`PrintBeam` API. Using the facade uninitialized throws `PrinterException.NotInitialized`.

```kotlin
fun initialize(config: PrintBeamConfig)
```

- Call it from `Application.onCreate` (Android) or the `App` initializer (iOS/SwiftUI).
- Guard against re-running it on configuration changes. A second call while any printer is
  connected throws `PrinterException.InvalidInput`.
- Otherwise, a second call replaces the configuration wholesale and tears the previous facade
  down exactly like `shutdown`. That path is intended for tests and app-level account
  switches, not for casual re-init.

### `PrintBeam.shutdown()`

Tears the facade down and returns it to the uninitialized state, so `initialize` can be called
again. Most apps never call this; it exists for tests and controlled teardown.

```kotlin
fun shutdown()
```

- Cancels any active scan and pending callbacks.
- Closes every held connection, best-effort, in the background.
- Resets all observed printer states to `Disconnected`.
- Idempotent: calling it on an uninitialized facade is a no-op.

---

## Discovery

### `PrintBeam.scan(transports, timeoutMs, listener)`

Starts a streaming discovery scan across the requested transports. Call it when your printer
picker opens.

```kotlin
fun scan(
    transports: Set<Transport>,          // e.g. setOf(Transport.NETWORK, Transport.BLE)
    timeoutMs: Long = 12_000,
    listener: ScanListener,
): ScanHandle
```

- **Network**: an mDNS/Bonjour browse plus a parallel TCP port-scan of the local /24 subnet
  on port 9100. Port-scan finds are asked for their ESC/POS `GS I` identity during the scan.
  Printers that don't advertise mDNS still show up named ("EPSON TM-m30", not a bare IP).
- **BLE**: a GATT scan filtered by known printer service UUIDs plus name heuristics.
- Results stream into `ScanListener.onPrinterFound` as printers respond. Don't wait for the
  end to populate UI.
- Every found printer is registered automatically. `connect` and `print` accept its id
  immediately, mid-scan included.
- Only one scan runs at a time. Starting a new scan cancels the previous one. Any
  connection-opening call (`connect`, or `print`'s auto-connect) also cancels the active scan
  first. This exists because the iOS shared `CBCentralManager` cannot scan and connect at the
  same time; the facade owns that constraint so you never see it.
- Throws `PrinterException.InvalidInput` if `transports` is empty. Returns a `ScanHandle`.

### `ScanListener`

Receives scan results. All callbacks arrive on the main dispatcher.

```kotlin
interface ScanListener {
    fun onPrinterFound(printer: DiscoveredPrinter)
    fun onTransportFailed(transport: Transport, cause: PrinterException)
    fun onFinished(printers: List<DiscoveredPrinter>)
}
```

- **`onPrinterFound`** — may fire more than once per printer id. When a later source enriches
  an earlier observation (port-scan finds a bare endpoint, then mDNS or `GS I` resolves its
  name), the entry is re-emitted with merged fields. **Key your UI list by `printer.id`** so
  enrichment replaces the row instead of appending a duplicate.
- **`onTransportFailed`** — one scan source failed, for example a denied BLE permission. This
  is informational; the other transports keep scanning.
- **`onFinished`** — the scan ran to completion. `printers` is the final deduplicated
  snapshot. Not invoked when the scan is cancelled by `ScanHandle.cancel`, a newer `scan`, a
  `connect`, or `shutdown`.

On iOS, a Swift class conforming to `ScanListener` must inherit `NSObject`.

### `ScanHandle.cancel()`

Stops the scan and suppresses `onFinished`. Call it when the scan UI is dismissed.
Idempotent; cancelling a finished scan is a no-op.

### `DiscoveredPrinter`

One found printer.

```kotlin
data class DiscoveredPrinter(
    val endpoint: PrinterEndpoint,
    val name: String?,
    val source: Source,              // MDNS, PORT_SCAN, BLE_SCAN, MANUAL
    val manufacturer: String? = null,
    val model: String? = null,
    val attributes: Map<String, String> = emptyMap(),  // raw mDNS TXT records
    val rssi: Int? = null,           // BLE signal strength, dBm
) {
    val id: String          // stable, endpoint-derived: "net://192.168.1.30:9100", "ble://AA:BB:…"
    val transport: Transport
}
```

- `id` is the stable identity used everywhere else in the SDK. It is derived purely from the
  endpoint, so the same physical printer gets the same id whether it was found by scanning or
  entered manually, today or after a relaunch.
- When two sources observe the same endpoint, their fields merge by source authority:
  mDNS > manual > BLE scan > port scan. The more authoritative side's non-null fields win, and
  the other side fills the gaps. A name you registered manually survives a nameless re-scan.

---

## The printer registry

`connect`, `print`, and the query methods all address printers by string id, resolved through
an in-memory registry. The registry is populated three ways: automatically by `scan`, and
explicitly by the two methods below.

### `PrintBeam.addManualPrinter(endpoint, name, paperWidth)`

Registers a printer the user configured by hand, such as an "enter IP address" flow. Returns
its stable id — the same id a scan would assign for that endpoint.

```kotlin
fun addManualPrinter(
    endpoint: PrinterEndpoint,
    name: String? = null,
    paperWidth: PaperWidth? = null,   // null → PrintBeamConfig.defaultPaperWidth
): String                             // the stable id
```

Re-registering an endpoint replaces its entry, name and paper width included. That also makes
it the idiomatic way to rename a printer after `queryDeviceInfo` resolves its identity.

### `PrintBeam.rememberPrinter(printer, paperWidth)`

Registers a `DiscoveredPrinter` object you already hold, typically a scan result restored from
persistence.

```kotlin
fun rememberPrinter(printer: DiscoveredPrinter, paperWidth: PaperWidth? = null): String
```

Unlike `addManualPrinter`, an existing entry is merged field by field rather than replaced.
Remembering a printer never erases richer metadata the registry already has.

### `PrintBeam.knownPrinters()`

Returns a snapshot of every registered printer — scan results, manual entries, and remembered
printers — in registration order.

```kotlin
fun knownPrinters(): List<DiscoveredPrinter>
```

### Persisting a printer across launches

The registry is in-memory, and ids alone cannot be parsed back into endpoints. To survive a
relaunch, persist the printer's endpoint and fields (or the values you passed to
`addManualPrinter`) and re-register on the next launch. Both registration calls derive the
identical id every time.

```kotlin
// On pick:
prefs.save(host, port, name, paperWidth)
// On next launch:
val id = PrintBeam.addManualPrinter(PrinterEndpoint.Network(host, port), name, paperWidth)
```

---

## Sessions

The facade holds one open connection per printer id across prints. On BLE that saves a
1–3 second GATT handshake per receipt. On network printers it saves the socket dial.

### `PrintBeam.connect(printerId)`

Opens and holds a connection. You rarely need to call this explicitly, because `print`
auto-connects. It is useful to warm the connection while the user is still on the cart screen,
or to validate a manually entered address immediately.

```kotlin
suspend fun connect(printerId: String)
fun connect(printerId: String, onResult: (PrinterException?) -> Unit)
```

- No-op if a session is already held.
- On failure, the suspend variant throws and the callback twin delivers: `NotInitialized`,
  `InvalidInput` for an unknown id, or a transport `PrinterException` when the open fails.
- Note the deliberate split: `connect` throws on failure, `print` doesn't. A failed open is an
  error of the connect call itself. A transport failure during printing is the outcome of a
  job that ran, reported as `PrintResult.Failure`.

### `PrintBeam.disconnect(printerId)`

Closes and forgets the held connection. Call it when the user switches printers or your
printing UI is torn down for good.

```kotlin
suspend fun disconnect(printerId: String)
fun disconnect(printerId: String, onResult: (PrinterException?) -> Unit)
```

- No-op when nothing is connected, unknown ids included.
- There is no idle timeout. A held session stays held until you disconnect or call `shutdown`.

### `PrintBeam.printerState(printerId)`

Returns an observable session lifecycle for one printer.

```kotlin
fun printerState(printerId: String): Flow<PrinterState>
```

- The flow is StateFlow-backed. It replays the latest state immediately on collection, then
  emits on every change.
- It conflates, so a fast `Connecting → Connected` flip may arrive as `Connected` alone.
- Ids not yet registered read as `Disconnected`.

### `PrinterState`

```kotlin
sealed class PrinterState {
    object Disconnected : PrinterState()  // no session held; the initial state
    object Connecting : PrinterState()    // a connection open is in flight
    object Connected : PrinterState()     // live session; the next print skips the handshake
    class Failed(val cause: PrinterException) : PrinterState()  // last open or print failed
}
```

`Failed` is a resting state. The next `connect` or `print` moves it back through `Connecting`.
From Swift, match with casts: `if let failed = state as? PrinterState.Failed`.

---

## Printing

### `PrintBeam.print(printerId) { … }`

Builds a receipt with the [DSL](#receipt-dsl-reference) and prints it on the held session,
auto-connecting when none is live.

```kotlin
suspend fun print(printerId: String, block: ReceiptBuilder.() -> Unit): PrintResult
fun print(printerId: String, block: ReceiptBuilder.() -> Unit, onResult: (PrintResult) -> Unit)
```

- Line wrapping uses the paper width recorded in the printer's registry entry.
- Concurrent prints to the same printer are serialized. Prints to different printers run in
  parallel.
- **Link-drop recovery**: if a write fails on a held connection, the SDK closes it, reopens
  once, and retries the write once. Only if the retry also fails do you get
  `PrintResult.Failure`. A printer that was power-cycled between prints usually just works.
- Failure model: transport failures, auto-connect included, come back as
  `PrintResult.Failure`. Only builder validation throws — for example invalid barcode data, or
  a multi-character `divider` string. The callback twin can't throw, so validation errors
  arrive there as `PrintResult.Failure` too.

```kotlin
val result = PrintBeam.print(printerId) {
    align(Alignment.CENTER)
    bold { size(2, 2) { text("FRESHCART") } }
    align(Alignment.LEFT)
    line("Coffee beans 1kg", "$18.00")
    divider("=")
    line("TOTAL", "$18.00")
    qrCode("https://example.com/order/1042")
    cut()
}
if (result is PrintResult.Failure) show(result.exception)
```

### `PrintResult`

```kotlin
sealed class PrintResult {
    object Success : PrintResult()
    data class Failure(val exception: PrinterException) : PrintResult()

    val isSuccess: Boolean  // true when this is Success
}
```

---

## Queries

### `PrintBeam.queryStatus(printerId)`

Reads real-time printer health via ESC/POS `DLE EOT`. A typical use is to query before a large
print job and warn on `!paperPresent` or `!coverClosed`.

```kotlin
suspend fun queryStatus(printerId: String): PrinterStatus?
fun queryStatus(printerId: String, onResult: (PrinterStatus?, PrinterException?) -> Unit)
```

- Runs over the held session, auto-connecting like `print`. Serialized with prints, so a
  status query never interleaves bytes with a receipt.
- Returns `null` only when the printer sends no reply within the read window. This is common
  for BLE printers that don't implement the read path. Treat null as "status not supported",
  not as an error.
- Transport failures propagate as `PrinterException`.

```kotlin
data class PrinterStatus(
    val online: Boolean,
    val coverClosed: Boolean,
    val paperPresent: Boolean,
    val errorPresent: Boolean,
)
```

### `PrintBeam.queryDeviceInfo(printerId)`

Reads printer identity via ESC/POS `GS I`: manufacturer, model, firmware, serial.

```kotlin
suspend fun queryDeviceInfo(printerId: String): DeviceInfo
fun queryDeviceInfo(printerId: String, onResult: (DeviceInfo?, PrinterException?) -> Unit)
```

- Fields the printer ignores come back null. `DeviceInfo.isEmpty` is true when it ignored all
  four, which is typical for BLE printers.
- Same session semantics as `queryStatus`.
- Since alpha03, the network scan already does this during discovery, so scan rows arrive
  named. The remaining consumer use is naming a printer that was entered manually or picked
  while still nameless:

```kotlin
val info = PrintBeam.queryDeviceInfo(id)
val name = listOfNotNull(info.manufacturer, info.model).joinToString(" ").ifBlank { null }
name?.let { PrintBeam.addManualPrinter(endpoint, it, paperWidth) }  // re-register, same id
```

```kotlin
data class DeviceInfo(
    val manufacturer: String?,  // GS I 66 — "EPSON", "Star Micronics"
    val model: String?,         // GS I 67 — "TM-m30", "TSP143IIIW"
    val firmware: String?,      // GS I 65
    val serial: String?,        // GS I 68
) {
    val isEmpty: Boolean        // true when all four fields are null
}
```

---

## Receipt DSL reference

The `block` of every `print` call receives a `ReceiptBuilder`. Each call appends ESC/POS bytes
to a buffer that is sent in a single transport write. The builder also works standalone: build
once, cache the bytes, then send later or to several printers via the L1 `Printer.sendRaw`.

### Text

| Method | What it does |
|---|---|
| `text(value)` | Prints `value` plus a line feed, encoded through the current [code page](#codepage). Characters the code page can't render go through the [fallback table](#textfallbacks) (`₹` → `Rs.`), and to `?` as the last resort. |
| `raw(value)` | Same as `text` but without the trailing line feed. |
| `unicodeText(value, fontSizeDots = 24, bold = false, align = LEFT)` | Renders `value` with the platform text engine and prints it as a raster image. This gives full Unicode fidelity (the real ₹ glyph, Devanagari, CJK, Arabic) on any ESC/POS printer, independent of code pages. Wraps at the paper width. Heavier than `text` (raster bytes vs one byte per char); prefer `text` + fallbacks when a code page can render the content. `align` is baked into the rendered image. |
| `line(left, right)` | Two-column line: `left` left-justified, `right` right-justified, padded to the paper's column count. Overlong `left` is truncated. An overlong `right` keeps its tail, so the meaningful suffix (cents) survives. Fallback substitution happens before the column math, so `₹135` measures as the 6 printed characters of `Rs.135`. |
| `divider(char = "-")` | Full-width rule of the given character. Takes a one-character `String`, not `Char`, because `Char` bridges awkwardly to Swift. Anything longer throws `InvalidInput`. |
| `fallback(char, replacement)` | Adds or overrides a fallback substitution for this receipt: `fallback("₹", "INR ")`. See [`TextFallbacks`](#textfallbacks) for the defaults. |

### Styling

| Method | What it does |
|---|---|
| `align(alignment)` | Sets alignment (`LEFT` / `CENTER` / `RIGHT`) for subsequent text, barcodes, and QR codes. Full-width rasters position by their own pixels instead. |
| `bold { … }` | Runs the block with emphasis on, then restores. |
| `underline(weight = 1) { … }` | Runs the block underlined (weight 1 or 2), then restores. |
| `size(width, height) { … }` | Runs the block at a text scale of 1–8× per axis, then restores 1×1. Column math in `line`/`divider` accounts for the active width multiplier. |
| `codePage(page)` | Switches the printer's character table (`ESC t n`) and the SDK-side encoder atomically, so bytes and glyph table always match. See [`CodePage`](#codepage). |

### Content blocks

| Method | What it does |
|---|---|
| `barcode(data, type, height = 80, moduleWidth = 3, hriBelow = true)` | 1D barcode. `data` is validated against the symbology (length/charset) and throws `InvalidInput` when it doesn't fit. Inherits the current `align`. Supported types: UPC-A, UPC-E, EAN-13, EAN-8, CODE39, ITF, CODABAR, CODE128. |
| `qrCode(data, moduleSize = 6, errorCorrection = 49)` | QR code (model 2). `moduleSize` 1–16 dots per module; `errorCorrection` 48–51 = L/M/Q/H. Inherits the current `align`. |
| `image(image, threshold = 128)` | Prints a `PlatformImage` (Android `Bitmap`, iOS `UIImage`) as a 1-bit raster scaled to the paper width. `threshold` (0–255) is the luminance cutoff for black. |
| `feed(lines = 1)` | Advances the paper. |
| `cut(partial = false)` | Feeds 3 lines, then cuts (full or partial, if the printer has a cutter). |
| `cashDrawer(pin = 0, onMs = 60, offMs = 120)` | Pulses the cash drawer on the printer's RJ11 port. |

### `toBytes()`

Snapshots the encoded ESC/POS bytes built so far. This is the standalone path:

```kotlin
val receipt = ReceiptBuilder(PaperWidth.MM_80).apply { text("HELLO"); cut() }.toBytes()
```

---

## Core types

### `PrinterEndpoint`

Where to reach a printer.

```kotlin
sealed class PrinterEndpoint {
    abstract val id: String           // "net://host:port" or "ble://deviceId"
    abstract val transport: Transport

    data class Network(val host: String, val port: Int = 9100) : PrinterEndpoint()

    data class Ble(
        val deviceId: String,
        val profile: BleProfile = BleProfile.NORDIC_UART,
    ) : PrinterEndpoint()
}
```

- `Ble.deviceId` is the MAC address on Android. On iOS it is a `CBPeripheral.identifier` UUID
  string, stable per app; Apple does not expose MAC addresses.
- The hierarchy is sealed by design. Third-party transports plug in via
  [`ConnectionFactory`](#connectionfactory--printerconnection), not by extending it.

### `Transport`

```kotlin
enum class Transport { NETWORK, BLE }
```

### `PaperWidth`

Physical roll width. `charsPerLine` drives two-column padding at the default Font A.
`dotsPerLine` clamps raster printing.

```kotlin
enum class PaperWidth(val charsPerLine: Int, val dotsPerLine: Int) {
    MM_58(32, 384), MM_76(42, 420), MM_80(48, 576)
}
```

### `BleProfile`

GATT characteristic layout for a BLE printer, with pacing settings tuned for cheap ESC/POS BLE
chips: small chunk sizes, inter-chunk delays, and a final drain window so long receipts don't
lose their tail. Three presets cover most hardware:

- **`BleProfile.NORDIC_UART`** (default) — Nordic UART service: Bixolon SPP-R200III, Xprinter
  XP-P323B, generic 58 mm printers.
- **`BleProfile.GENERIC_ESCPOS`** — the 0xFF00 service used by GoodCom RPP02N, Xprinter
  variants, and most no-name chips. The SDK also auto-detects the writable characteristic at
  connect time, so picking the exact profile only saves the discovery step.
- **`BleProfile.STAR_BLE`** — Star Micronics GATT printers (SM-L200 class). Not the
  TSP100IIIBI, which uses Star's MFi accessory protocol over Bluetooth Classic and is out of
  scope.

All fields (`serviceUuid`, `writeCharacteristicUuid`, `mtu`, `maxChunkBytes`, `writePaceMs`,
`finalDrainMs`, …) are documented in Dokka. Construct your own profile for unusual hardware.

### `CodePage`

```kotlin
enum class CodePage(val escPosCode: Int) { CP437, CP1252 }
```

Selecting a code page via `ReceiptBuilder.codePage` switches the printer's character table and
the SDK's string encoder together. If the two get out of sync, receipts print the wrong
characters for non-ASCII text. `CP437` is the factory default of virtually every ESC/POS
printer. `CP1252` adds €, smart quotes, and the Latin-1 supplement.

### `TextFallbacks`

`TextFallbacks.DEFAULT` is the built-in substitution table for characters no classic code page
has. It covers modern currency signs (`₹` → `Rs.`, `€` → `EUR` under CP437, `₩` → `KRW`, …)
and typographic punctuation that copy-paste sneaks in: smart quotes → straight quotes,
em-dash → `--`, ellipsis → `...`. Substitution is conditional on the active code page; `€`
prints natively under CP1252. Override per receipt with `ReceiptBuilder.fallback`. For the
real glyphs, use `unicodeText`.

### `PlatformImage` / `PrinterContext`

`expect` classes bridging platform handles: `PlatformImage(bitmap)` on Android,
`PlatformImage(uiImage)` on iOS; `PrinterContext(context)` on Android, `PrinterContext()` on
iOS. From Swift, a file constructing `PrinterContext` with an external central manager must
`import CoreBluetooth`.

### `PrinterException`

Base type of every failure. Each subtype carries a stable `code` string for programmatic
matching. Match on `code` rather than class when consuming from Swift, where bridged Kotlin
subtype checks are unreliable.

| Subtype | `code` | When |
|---|---|---|
| `ConnectFailed` | `connect_failed` | TCP dial or GATT connect failed (carries `host`/`port`). |
| `WriteFailed` | `write_failed` | Transport write failed mid-job. |
| `ReadFailed` | `read_failed` | Transport read failed (status/info queries). |
| `Timeout` | `timeout` | Operation exceeded its window (carries `operation`, `timeoutMs`). |
| `NotConnected` | `not_connected` | Operation on a connection that was never opened (L1 misuse). |
| `InvalidInput` | `invalid_input` | Caller error: unknown printer id, bad barcode data, empty transport set… |
| `NotInitialized` | `not_initialized` | Facade used before `PrintBeam.initialize`. |
| `PermissionDenied` | `permission_denied` | Android runtime permission missing (`BLUETOOTH_*`, location). |
| `BluetoothUnavailable` | `bluetooth_unavailable` | Adapter missing, off, or unauthorized (iOS). |
| `DiscoveryFailed` | `discovery_failed` | One scan source failed; carried on `onTransportFailed`. |

### `PrinterLogger`

The SDK's only output channel. Silent by default.

```kotlin
fun interface PrinterLogger {
    fun log(level: LogLevel, tag: String, message: String, throwable: Throwable?)

    companion object {
        val NoOp: PrinterLogger   // drops every call
    }
}

enum class LogLevel { VERBOSE, DEBUG, INFO, WARN, ERROR }
```

- Bridge it to Timber, Kermit, OSLog, or Crashlytics in one lambda.
- Calls are synchronous on internal threads. Implementations must be thread-safe.
- Breadcrumbs cover discovery, GATT negotiation (MTU, characteristic pick), chunked writes,
  and failure paths. Useful when a customer's no-name BLE printer misbehaves in the field.

---

## Level 1 API (advanced)

The facade is built entirely on these public seams. Use them directly when you need one-shot
prints, custom discovery orchestration, or your own transport.

### `Printer`

Transport-agnostic one-shot client. Every operation opens a fresh connection, performs the
job, and closes it. Thread-safe: operations on one instance serialize through a mutex.

```kotlin
class Printer(
    endpoint: PrinterEndpoint,
    paperWidth: PaperWidth = PaperWidth.MM_80,
    connectTimeoutMs: Long = 5_000,
    ioTimeoutMs: Long = 10_000,
    context: PrinterContext? = null,       // required for BLE endpoints
    logger: PrinterLogger = PrinterLogger.NoOp,
    connectionFactory: ConnectionFactory = DefaultConnectionFactory(logger),
)
```

All methods below are suspend functions.

| Method | What it does |
|---|---|
| `print(block: ReceiptBuilder.() -> Unit): PrintResult` | Builds a receipt with the same DSL and sends it. Transport failures return `Failure`; only builder validation throws. |
| `sendRaw(bytes: ByteArray): PrintResult` | Sends pre-encoded ESC/POS bytes. Pair it with a standalone `ReceiptBuilder` for pre-rendered or fan-out printing. |
| `queryStatus(): PrinterStatus?` | `DLE EOT` status. Null means the printer sent no reply. |
| `queryDeviceInfo(): DeviceInfo` | `GS I` identity. Unanswered fields are null. |
| `kickCashDrawer(pin = 0, onMs = 60, offMs = 120): PrintResult` | Drawer pulse without printing. |

When using the facade, prefer `PrintBeam.queryStatus`/`queryDeviceInfo` over the `Printer`
ones. The L1 path opens a second connection next to the facade's held one, which on BLE means
a whole extra GATT handshake.

### Retry helpers

Exponential-backoff retry for the case where the printer is there but doesn't answer on the
first try. Only `ConnectFailed` and `Timeout` retrigger. Input, permission, and
Bluetooth-state failures return immediately because another attempt can't help.

```kotlin
suspend fun retryOnTransient(
    maxAttempts: Int = 3,
    initialDelayMs: Long = 250,
    backoffFactor: Double = 2.0,
    block: suspend () -> PrintResult,
): PrintResult

suspend fun Printer.printWithRetry(
    maxAttempts: Int = 3,
    initialDelayMs: Long = 250,
    backoffFactor: Double = 2.0,
    block: ReceiptBuilder.() -> Unit,
): PrintResult
```

### `PrinterDiscoveryService`

The discovery engine underneath `PrintBeam.scan`, for consumers who want flows instead of
listeners:

- `discover(timeout: Duration, transports: Set<Transport>): Flow<DiscoveryEvent>` —
  streaming `Found` / `TransportFailed` events, already deduplicated and enrichment-merged.
- `suspend fun scanOnce(timeout: Duration, transports: Set<Transport>): List<DiscoveredPrinter>`
  — runs one scan to completion and returns the deduplicated list. A `scanOnce(timeoutMs: Long, …)`
  overload exists for Swift, where `Duration` doesn't bridge.
- `suspend fun detectBleProfile(endpoint: PrinterEndpoint.Ble, connectTimeoutMs: Long = 5_000): BleProfile?`
  — probes an unknown BLE printer and returns the matching known profile, or null if none match.
- `describeScanRange(): String?` — human-readable subnet description ("192.168.1.0/24") for
  scan UI.
- Tunables via `NetworkScanOptions` (port, per-host timeout, concurrency, and
  `enablePortScan = false` for BYO-network environments where a 253-host SYN sweep would trip
  intrusion detection) and `BleScanOptions` (service UUID filters, name hints).

### `ConnectionFactory` / `PrinterConnection`

The transport seam.

```kotlin
fun interface ConnectionFactory {
    fun create(
        endpoint: PrinterEndpoint,
        context: PrinterContext?,
        connectTimeoutMs: Long,
        ioTimeoutMs: Long,
    ): PrinterConnection
}

interface PrinterConnection {
    suspend fun open()
    suspend fun write(bytes: ByteArray)
    suspend fun read(maxBytes: Int, timeoutMs: Long): ByteArray
    suspend fun close()
}
```

`DefaultConnectionFactory` dispatches `Network` endpoints to a Ktor TCP connection and `Ble`
endpoints to the platform GATT transport. Supply your own factory in `PrintBeamConfig` (or to
`Printer`) to add a transport the SDK doesn't ship — USB, serial, a test fake — without
touching the sealed endpoint hierarchy.
