# Contributing

Short version: **bug reports and printer compatibility reports are extremely welcome, code
contributions are not accepted.**

## Why pull requests are not accepted

PrintBeam's source is closed. This repository contains the published binaries, the
documentation and the Swift Package manifest, but not the implementation. There is nowhere
here for a code change to land, and accepting outside code into a proprietary codebase raises
ownership questions that are not worth creating for a project this size.

That is a decision about licensing, not a comment on anyone's code. If you have a fix in mind,
describe it in an issue. Good descriptions of problems are more valuable to this project than
patches would be.

## What genuinely helps

**Printer reports.** This is the single most useful thing anyone can contribute. The SDK is
tested on the hardware one person owns, which is two printers. Every report of a printer that
works, or fails, makes it better for everyone. See the
[compatibility list](docs/COMPATIBILITY.md) for what has been confirmed so far, and open a
[compatibility report](https://github.com/kotimadduluri/printbeam-sdk/issues/new?template=printer_report.yml)
either way. Working printers are worth reporting too, not just broken ones.

**Bug reports.** Use the
[bug report form](https://github.com/kotimadduluri/printbeam-sdk/issues/new?template=bug_report.yml).
It asks for the printer make and model, the transport, and logger output, because a printing
bug without those is usually impossible to diagnose. Attaching a photo of a misprinted receipt
is often the fastest way to communicate what went wrong.

**Documentation problems.** If something in the [docs](https://kotimadduluri.github.io/printbeam-sdk/)
is wrong, unclear, or missing, open an issue. Documentation fixes are the one area where a
suggested wording is directly usable.

**Questions.** Open an issue. If you were confused by something, the documentation probably
caused it, and the answer usually belongs in the docs rather than only in a thread.

## Getting logs

The SDK is silent by default. Almost every report is easier to act on with logging turned on:

```kotlin
PrintBeam.initialize(PrintBeamConfig(
    context = PrinterContext(applicationContext),
    logger = PrinterLogger { level, tag, message, throwable ->
        Log.println(Log.INFO, tag, message)
    },
))
```

## Security issues

Do not open a public issue. Follow [SECURITY.md](SECURITY.md) instead.
