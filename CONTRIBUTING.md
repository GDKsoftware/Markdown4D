# Contributing to Markdown4D

Thanks for looking at the code. This page covers what you need to build it, run
the tests and get a change merged.

## What you need

- **RAD Studio / Delphi 12 Athens (23.0) or Delphi 13 (37.0)**, Win32 and
  Win64x. The library itself is plain Object Pascal and uses only the RTL,
  the VCL and FMX.
- Nothing else to install. Everything the sources need is in the repository.

## Building

Open `Markdown4D.groupproj` in the IDE for day-to-day work.

For the full sweep, run from the repository root:

```bat
build.bat
```

That builds and runs both DUnitX suites, builds all four examples and all five
packages (Win32, plus the VCL packages on Win64x), and regenerates the
conformance table in the README. The script looks for the newest installed
Delphi; set `MARKDOWN4D_STUDIO` to a version number such as `23.0` to force a
different one.

## Tests

Two suites:

- `Tests\Markdown4D.Tests.dproj`: parser, AST, renderer, writer, layout,
  editor model, extensions, VCL components, and the specification corpora.
- `Tests\Markdown4D.Fmx.Tests.dproj`: the FMX components. Separate because the
  frameworks cannot live in one executable.

Every change needs tests. Name them `Subject_Scenario_Expectation`, the way the
existing fixtures do, for example
`LineBreak_NestedBullet_KeepsNesting`. A bug fix starts with a test that fails
before the fix.

Behaviour changes to the parser or renderer must keep the CommonMark and GFM
corpora at 100 percent. See `Tests/specs/README.md` for what those corpora are.

## Architecture rules

The layering is the load-bearing part of the design, so a change that breaks it
will not be merged:

- `Source\Core` and `Source\Layout` are framework-neutral. They must not
  reference `Vcl.*` or `FMX.*`, directly or indirectly.
- Only `Source\Vcl` and `Source\Fmx` know about a framework, and each of them
  is a thin shell over the shared layout engine.
- New features belong in the library and its components, not in the example
  applications. The examples demonstrate the library; they are not where
  behaviour lives.
- No new external dependencies without discussing it in an issue first.

## Code style

Follow what is already there. In short: descriptive names without
abbreviations, `const` for parameters that are not written to, guard clauses
instead of deep nesting, one blank line between the logical steps of a method,
an explicit `else` on every `case` over an enum, and a comment only where it
explains *why*, never *what*.

## Pull requests

- One subject per pull request.
- Tests included, and both suites green.
- Update the docs under `docs/` when you change public behaviour.

Found a security problem instead? Please read [SECURITY.md](SECURITY.md) and
report it privately.
