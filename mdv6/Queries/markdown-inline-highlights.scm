; Derived (R-43): upstream `tree-sitter-markdown-inline` v0.5.3 with the same palette mapping
; (`@text.strong` -> `@function`, `@text.emphasis` -> `@type`, `@text.literal` -> `@string`,
; `@text.uri` -> `@attribute`, `@text.reference` -> `@label`). Loaded as the embedded pass of a
; `markdown` fence (C-05).
; From nvim-treesitter/nvim-treesitter
[
  (code_span)
  (link_title)
] @string

[
  (emphasis_delimiter)
  (code_span_delimiter)
] @punctuation.delimiter

(emphasis) @type

(strong_emphasis) @function

[
  (link_destination)
  (uri_autolink)
] @attribute

[
  (link_label)
  (link_text)
  (image_description)
] @label

[
  (backslash_escape)
  (hard_line_break)
] @string.escape

(image
  [
    "!"
    "["
    "]"
    "("
    ")"
  ] @punctuation.delimiter)

(inline_link
  [
    "["
    "]"
    "("
    ")"
  ] @punctuation.delimiter)

(shortcut_link
  [
    "["
    "]"
  ] @punctuation.delimiter)

; NOTE: extension not enabled by default
; (wiki_link ["[" "|" "]"] @punctuation.delimiter)
