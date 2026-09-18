# Links

A [sibling document](links-sibling.md) navigates in-app and ⌘← returns (T-22, R-19).

Same-document fragments: [#example](#example) reaches the first `### Example`; [#example-1](#example-1) matches nothing; [#a---b](#a---b), [#c--rust](#c--rust) and [#draft-notes](#draft-notes) reach the GitHub-style slugs; [#deep](#deep) (an h4) and [#setext](#setext) stay unmatched; a percent-encoded fragment [#%C3%BCnicode](#%C3%BCnicode).

Cross-file: [sibling fragment](links-sibling.md#second-heading) loads the sibling at that heading; [missing fragment](links-sibling.md#nope) loads it at the top.

External and broken: [https](https://example.com) opens the browser; [broken](does-not-exist.md) does not navigate; [text file](notes.txt) goes to the system opener.

### Example

First example.

### Example

Second example (the fragment resolves to the first).

### a - b

### C++ & Rust

### _Draft_ notes

### Ünicode

#### deep

Setext
======
