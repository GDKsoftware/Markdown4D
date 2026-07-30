# Test corpora

Where the JSON files in this folder come from, and under which terms they are
included.

## commonmark-0.31.2.json

The 652 examples of the CommonMark specification, version 0.31.2, in the
`spec.json` form generated from `spec.txt`. Each entry carries `markdown`,
`html`, `example`, `start_line`, `end_line` and `section`.

- Upstream: <https://spec.commonmark.org/0.31.2/spec.json>
- Specification: <https://spec.commonmark.org/0.31.2/>
- Copyright: John MacFarlane and the CommonMark contributors
- Licence: Creative Commons CC-BY-SA 4.0, the licence of the CommonMark
  specification. See <https://creativecommons.org/licenses/by-sa/4.0/>.

## gfm-0.29.json

The extension examples of the GitHub Flavored Markdown specification, version
0.29-gfm: tables, task list items, strikethrough, extended autolinks and the
tag filter. Same entry shape as the CommonMark corpus, with the example numbers
of the GFM specification.

- Specification: <https://github.github.com/gfm/>
- Copyright: GitHub, Inc. and the CommonMark contributors
- Licence: Creative Commons CC-BY-SA 4.0, as a derivative of the CommonMark
  specification.

## charts.json and mermaid.json

Written for this project and covered by the repository's MIT licence. They are
not specification corpora: alongside `markdown` they carry the expected parse
outcome for the bundled chart and mermaid extensions (diagram kind, node and
edge counts, dataset and label counts), because neither extension has an
upstream conformance suite.

## Updating a corpus

Replace the file, keep the version in the file name, update the entry above,
and check the example count asserted in `Markdown4D.Parser.Spec.Tests.pas`
(`CommonMark_Corpus_ContainsAllExamples`) plus the badge in the root README.
