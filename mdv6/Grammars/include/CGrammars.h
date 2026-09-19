// CGrammars — the eighteen vendored tree-sitter grammars compiled into mdv6 (K-05, R-38, R-43).
#ifndef CGRAMMARS_H
#define CGRAMMARS_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct TSLanguage TSLanguage;

const TSLanguage *tree_sitter_c(void);
const TSLanguage *tree_sitter_go(void);
const TSLanguage *tree_sitter_rust(void);
const TSLanguage *tree_sitter_bash(void);
const TSLanguage *tree_sitter_javascript(void);
const TSLanguage *tree_sitter_yaml(void);
const TSLanguage *tree_sitter_toml(void);
const TSLanguage *tree_sitter_python(void);
const TSLanguage *tree_sitter_ruby(void);
const TSLanguage *tree_sitter_swift(void);
const TSLanguage *tree_sitter_sql(void);
const TSLanguage *tree_sitter_cpp(void);
const TSLanguage *tree_sitter_json(void);
const TSLanguage *tree_sitter_lua(void);
const TSLanguage *tree_sitter_opencl(void);
const TSLanguage *tree_sitter_perl(void);
const TSLanguage *tree_sitter_markdown(void);
const TSLanguage *tree_sitter_markdown_inline(void);

#ifdef __cplusplus
}
#endif

#endif
