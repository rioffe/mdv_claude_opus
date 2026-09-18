# Vendored tree-sitter grammars (K-05, R-38)

Each directory holds the generated `src/parser.c`, the external `src/scanner.c` where the grammar has one, the
`src/tree_sitter/*.h` headers the sources include, and the grammar's `LICENSE`. The highlight queries live in
`mdv6/Queries/<lang>-highlights.scm` (copied from each grammar's `queries/highlights.scm`). All eleven are
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
