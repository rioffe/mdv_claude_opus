# Vendored tree-sitter grammars (K-05, R-38, R-43)

Each directory holds the generated `src/parser.c`, the external `src/scanner.c` where the grammar has one, the
`src/tree_sitter/*.h` headers the sources include, and the grammar's `LICENSE`. The highlight queries live in
`mdv6/Queries/<lang>-highlights.scm` (copied from each grammar's `queries/highlights.scm`). All eighteen are
compiled into the `CGrammars` target (`Package.swift`) and loaded by `CodeRenderer` (C-05) against the
tree-sitter 0.25 runtime (ABI 14/15). Nothing is regenerated here: `grammar.js`, bindings and tests are not
vendored (D-15: the Swift grammar's `parser.c` is ~20 MB generated and is taken from the
`-with-generated-files` tag).

| Language | Repository | Tag | Commit | Licence |
| -------- | ---------- | --- | ------ | ------- |
| c | https://github.com/tree-sitter/tree-sitter-c | v0.24.2 | b780e47fc780ddc8da13afa35a3f4ed5c157823d | MIT |
| go | https://github.com/tree-sitter/tree-sitter-go | v0.25.0 | 1547678a9da59885853f5f5cc8a99cc203fa2e2c | MIT |
| rust | https://github.com/tree-sitter/tree-sitter-rust | v0.24.2 | 77a3747266f4d621d0757825e6b11edcbf991ca5 | MIT |
| bash | https://github.com/tree-sitter/tree-sitter-bash | v0.25.1 | a06c2e4415e9bc0346c6b86d401879ffb44058f7 | MIT |
| javascript | https://github.com/tree-sitter/tree-sitter-javascript | v0.25.0 | 44c892e0be055ac465d5eeddae6d3e194424e7de | MIT |
| yaml | https://github.com/tree-sitter-grammars/tree-sitter-yaml | v0.7.2 | 7708026449bed86239b1cd5bce6e3c34dbca6415 | MIT (`schema.core.c` is `#include`d by `scanner.c`, not compiled separately) |
| toml | https://github.com/tree-sitter-grammars/tree-sitter-toml | v0.7.0 | 64b56832c2cffe41758f28e05c756a3a98d16f41 | MIT |
| python | https://github.com/tree-sitter/tree-sitter-python | v0.25.0 | 293fdc02038ee2bf0e2e206711b69c90ac0d413f | MIT |
| ruby | https://github.com/tree-sitter/tree-sitter-ruby | v0.23.1 | 71bd32fb7607035768799732addba884a37a6210 | MIT |
| swift | https://github.com/alex-pinkus/tree-sitter-swift | 0.7.3-with-generated-files | 31d17fe7e818a2048c808b5c6fdc2dc792f4f5b5 | MIT |
| sql | https://github.com/DerekStride/tree-sitter-sql | v0.3.11 (release tarball `tree-sitter-sql-v0.3.11.tar.gz`, sha256 `a97a324eae9c81ed68f6e162b9b33f8911fc6442caa2950e57c498e2460d1387`; the tag's tree carries no generated parser) | 7b51ecda191d36b92f5a90a8d1bc3faef1c7b8b8 (tag) | MIT |
| cpp | https://github.com/tree-sitter/tree-sitter-cpp | v0.23.4 | f41e1a044c8a84ea9fa8577fdd2eab92ec96de02 | MIT |
| json | https://github.com/tree-sitter/tree-sitter-json | v0.24.8 | ee35a6ebefcef0c5c416c0d1ccec7370cfca5a24 | MIT |
| lua | https://github.com/tree-sitter-grammars/tree-sitter-lua | v0.5.0 | 10fe0054734eec83049514ea2e718b2a56acd0c9 | MIT (licence file is `LICENSE.md`) |
| opencl | https://github.com/lefp/tree-sitter-opencl | none — pinned by commit (the repository has no tag; last push 2023-03-30) | 8e1d24a57066b3cd1bb9685bbc1ca9de5c1b78fb | MIT |
| perl | https://github.com/tree-sitter-perl/tree-sitter-perl | v2.0.0 (release tarball `tree-sitter-perl.tar.gz`, sha256 `f73ba0711b4ac612ff3565ad4de92ee3afac0043a5176898b73a0998bb6aaf5e`; the tag's tree carries no generated parser) | 50904961d6a87c5191e611276aa2ecb9d66ca4ff (tag) | MIT |
| markdown | https://github.com/tree-sitter-grammars/tree-sitter-markdown | v0.5.3 (the `split_parser` layout: the block grammar is `tree-sitter-markdown/`, the inline grammar beside it) | f969cd3ae3f9fbd4e43205431d0ae286014c05b5 | MIT |
| markdown-inline | https://github.com/tree-sitter-grammars/tree-sitter-markdown | v0.5.3 (`tree-sitter-markdown-inline/`) | f969cd3ae3f9fbd4e43205431d0ae286014c05b5 | MIT |

## Derivations (R-43)

The eleven grammars of K-05/R-38 are vendored exactly as their upstream trees ship them, and so are three
of R-43's: `json`, `lua` and `opencl`. The rest carry a change, each stated in a header comment in the file
itself:

| File | Change | Why |
| ---- | ------ | --- |
| `Queries/cpp-highlights.scm` | the `c` query followed by upstream `tree-sitter-cpp`'s own | upstream's file assumes an inherited C query (it captures keywords, strings and types only) |
| `Queries/perl-highlights.scm` | upstream's file with `#lua-match?` → `#match?` on the shebang pattern | `#lua-match?` is a Neovim-only predicate; the pattern is a plain regex |
| `Queries/markdown-highlights.scm`, `Queries/markdown-inline-highlights.scm` | upstream's two files with the Neovim capture names mapped onto the palette vocabulary of C-05 (`@text.title` → `@keyword`, `@text.literal` → `@string`, `@text.uri` → `@attribute`, `@text.reference` → `@label`, `@text.strong` → `@function`, `@text.emphasis` → `@type`) | `text.*` has no `CodePalette` entry, so upstream's names would render every markdown capture plain |
| `opencl/src/parser.c` | line 1: `#include <tree_sitter/parser.h>` → `#include "tree_sitter/parser.h"` | the grammar predates the quoted-include convention; the angled form does not resolve inside the `CGrammars` target |
| `perl/src/*.h` | `bsearch.h` and `tsp_*.h` are vendored beside `src/tree_sitter/` | `perl/src/scanner.c` `#include`s them |

Markdown is the one language with two grammars: the block grammar colours the document structure and leaves
every `(inline)` span whole, so `CodeRenderer` re-parses each such span with the inline grammar and colours it
too (C-05). Metal has no grammar of its own: no Metal grammar with a licence file exists (the candidates on
GitHub ship no `LICENSE`), and the shading language is C++14-based, so a `metal` fence resolves to the C++
grammar (C-05, D-45).

