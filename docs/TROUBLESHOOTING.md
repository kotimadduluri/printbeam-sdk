---
title: Troubleshooting
seo_title: "Troubleshooting ESC/POS Printer Problems"
description: Fixes for the common failure modes - empty printer scans, BLE printers that connect but do not print, wrong characters, and permission problems.
---

# Troubleshooting

First move for any printing problem: attach a logger. The SDK is silent by default,
and its breadcrumbs (discovery, connection negotiation, chunked writes) usually name
the failure outright.

```kotlin
PrintBeam.initialize(PrintBeamConfig(
    context = PrinterContext(applicationContext),
    logger = PrinterLogger { level, tag, message, throwable ->
        Log.println(Log.INFO, tag, message)
    },
))
```

## Scan finds no network printers

Work through these in order:

1. **Same network?** The phone and printer must be on the same subnet. Guest Wi-Fi,
   VLANs, and access points with "client isolation" block device-to-device traffic
   entirely. Verify from a laptop on the same Wi-Fi: `nc -z 192.168.1.50 9100`
   (or open a TCP connection to port 9100 any other way).
2. **Android emulator?** Emulators sit on an isolated NAT network (`10.0.2.x`) and
   cannot see your LAN. This is an emulator property, not a bug. Test on a real
   device, or use `addManualPrinter` with the host machine's forwarding.
3. **iOS Simulator?** Bonjour announcements from devices on the host's LAN don't
   reliably reach Simulator processes. Test on a real iPhone.
4. **iOS device, scan silently empty?** `NSLocalNetworkUsageDescription` or
   `NSBonjourServices` is missing from Info.plist. iOS fails these without any error:
   the browse callback just never fires. See
   [Getting started](GETTING-STARTED.md), iOS tab, step 2.
5. **Printer has no mDNS?** Many cheap printers don't advertise Bonjour. The SDK's
   parallel port-scan of the local /24 subnet finds them anyway, so they appear a few
   seconds later than mDNS results, already named via their ESC/POS identity.
6. **Corporate, hotel, or NAC-enforced network?** The port scan probes 253 hosts,
   which intrusion detection can flag or block. Ship
   `NetworkScanOptions(enablePortScan = false)` for those environments and offer
   manual IP entry instead.

## Scan finds no BLE printers

- **Android**: the runtime permissions are missing or denied. `scan` reports this as
  `onTransportFailed(BLE, PermissionDenied)` rather than throwing. Request
  `BluetoothPermissions.required()`, and call `BluetoothPermissions.notifyChanged()`
  from your permission-result callback so the scan re-fires by itself.
- **iOS**: `NSBluetoothAlwaysUsageDescription` is missing. CoreBluetooth enters the
  `unauthorized` state silently: no prompt appears and scans return nothing.
- **iOS Simulator**: has no Bluetooth stack at all; `CBCentralManager` reports
  `poweredOff`. BLE requires a real device.
- The printer may already be connected to another phone. Most BLE printers stop
  advertising while they hold a connection. Power-cycle the printer.

## BLE printer connects but prints nothing, or truncates the receipt

Cheap BLE printer chips have tiny input buffers and lie about their throughput. The
SDK already paces writes conservatively, but some hardware needs more headroom.
Construct a custom profile with smaller chunks and a longer drain:

```kotlin
val gentle = BleProfile.GENERIC_ESCPOS.copy(
    maxChunkBytes = 60,     // smaller writes for tiny input buffers
    finalDrainMs = 1000,    // hold the link open so the radio finishes sending
)
val id = PrintBeam.addManualPrinter(
    PrinterEndpoint.Ble(deviceId = deviceId, profile = gentle),
)
```

If the receipt still stops partway, attach the logger and check which characteristic
was picked during connection: the SDK auto-detects the writable characteristic, and
the breadcrumbs show the choice. Unusual multi-service hardware sometimes needs an
explicit `BleProfile` with the vendor's service UUID.

## Characters print wrong (boxes, question marks, mojibake)

ESC/POS printers are code-page devices, not Unicode devices.

- **€, £, é, ñ print as boxes**: switch the code page inside the receipt:
  `codePage(CodePage.CP1252)`. The SDK updates the printer's character table and its
  own encoder together.
- **₹ prints as `Rs.`**: that's the built-in fallback table keeping column math
  intact on printers whose code pages predate the rupee sign. Override per receipt
  with `fallback("₹", "INR ")`, or print the real glyph with `unicodeText("₹135")`,
  which renders through the platform text engine as a raster and works on any printer
  and any script (Devanagari, CJK, Arabic).

## `queryStatus` returns null

Not an error. The printer sent no reply within the read window, which is normal for
BLE printers that don't implement the read path. Treat null as "status not
supported" and print anyway.

## `PrinterException.NotInitialized`

A `PrintBeam` method ran before `PrintBeam.initialize`. Initialize once per process
at the app entry point, before any UI that might scan or print. If you initialize in
an Activity, guard against re-running on configuration changes; re-initializing
while a printer is connected throws `InvalidInput`.

## Prints work, then fail after the printer was power-cycled

Usually invisible: when a write fails on a held connection, the SDK closes it,
reopens once, and retries the write before reporting failure. If you still get
`PrintResult.Failure` with `ConnectFailed`, the printer isn't reachable at its old
address: DHCP may have handed it a new IP. Rescan, or give the printer a static
address; BLE device ids and `net://` ids are stable, but an IP lease is not.

## First print fails after the app was in the background on a handheld

The facade holds a connection between prints, which assumes the device stays awake. That is
true of a till with the screen on and power connected, and Android's Doze never engages under
those conditions. It is not true of a battery-powered handheld that sleeps in a pocket: the OS
can close the socket underneath the held session without notifying the SDK.

You normally see this as one slower print rather than a failure, because a failed write closes
the connection, reopens it, and retries once. If you want to avoid it entirely, drop the
session when your app backgrounds:

```kotlin
override fun onStop() {
    super.onStop()
    lifecycleScope.launch { PrintBeam.disconnect(printerId) }
}
```

The next print reconnects cleanly. On BLE that costs the 1 to 3 second handshake once, which
is the trade you want on a device that sleeps.

## Cleartext / network security policy errors on Android

Thermal printers speak plain TCP; there is no TLS. If your app ships a strict
`network_security_config.xml`, allowlist the printer subnet with
`cleartextTrafficPermitted="true"` for those addresses.

## Still stuck

Open an [issue](https://github.com/kotimadduluri/printbeam-sdk/issues) with the
printer's make and model, the transport, and the logger output from one failing
attempt. That combination is almost always enough to diagnose.
