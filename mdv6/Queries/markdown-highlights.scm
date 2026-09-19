; Derived (R-43): upstream `tree-sitter-markdown` v0.5.3 with its Neovim capture names mapped onto the
; palette vocabulary of C-05 (`@text.title` -> `@keyword`, `@text.literal` -> `@string`, `@text.uri` ->
; `@attribute`, `@text.reference` -> `@label`). The block grammar leaves every `(inline)` span to the
; inline grammar, which CodeRenderer runs as an embedded pass (C-05).
;From nvim-treesitter/nvim-treesitter
(atx_heading
  (inline) @keyword)

(setext_heading
  (paragraph) @keyword)

[
  (atx_h1_marker)
  (atx_h2_marker)
  (atx_h3_marker)
  (atx_h4_marker)
  (atx_h5_marker)
  (atx_h6_marker)
  (setext_h1_underline)
  (setext_h2_underline)
] @punctuation.special

[
  (link_title)
  (indented_code_block)
  (fenced_code_block)
] @string

(fenced_code_block_delimiter) @punctuation.delimiter

(code_fence_content) @none

(link_destination) @attribute

(link_label) @label

[
  (list_marker_plus)
  (list_marker_minus)
  (list_marker_star)
  (list_marker_dot)
  (list_marker_parenthesis)
  (thematic_break)
] @punctuation.special

[
  (block_continuation)
  (block_quote_marker)
] @punctuation.special

(backslash_escape) @string.escape
