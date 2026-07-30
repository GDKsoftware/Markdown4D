# Security policy

Markdown4D turns text that an application did not write into HTML, into a
rendered document and into clickable links. Everything below is about that
boundary.

## Reporting a vulnerability

Please report privately, not through a public issue:

- GitHub: **Security → Report a vulnerability** on
  <https://github.com/GDKsoftware/Markdown4D>, or
- e-mail **marco@gdksoftware.com** with `Markdown4D` in the subject.

Include the markdown that triggers it, the API you called (`ToHtml`,
`ToUnsafeHtml`, a pipeline, or a viewer component), the Delphi version and the
platform. A minimal reproducing document says more than a description.

You can expect an acknowledgement within a few working days. Please give us a
reasonable window to ship a fix before publishing.

## What counts as a vulnerability

The library makes two promises, and a way around either one is a vulnerability:

1. **`TMarkdown.ToHtml` renders safely.** Raw HTML is dropped and destinations
   using `javascript:`, `vbscript:`, `file:` or a non-image `data:` scheme are
   emptied. Any input that gets script or a scripting destination into the
   output of `ToHtml` is in scope, including tricks with entities, whitespace,
   control characters or casing.
2. **The viewer components only reach out where the host allows.** Anything
   that makes a viewer fetch an address the host's image settings or the
   `OnRemoteImageRequest` event should have refused, or that makes it read a
   file outside the folder the host restricted it to, is in scope.

Also in scope: memory-safety problems, and input that makes the parser consume
disproportionate time or memory relative to its size.

## What does not count

- **`TMarkdown.ToUnsafeHtml` and the `UnsafeHtml` / `UnsafeLinks` pipeline
  options.** These reproduce the specification byte for byte and pass raw HTML
  and every destination through untouched. That is their documented purpose;
  only use them on input you trust, or sanitise the result afterwards.
- Behaviour of the example applications under `Examples/`, unless the same
  problem exists in the library itself. They are demonstrations, not products.
- Anything that requires the host application to hand the library input it
  already fully controls.

## Supported versions

Fixes land on `main` and go out in the next release. There are no long-lived
maintenance branches.
