[Works with pandoc](https://github.com/cdivita/pandoc-curly-switch/actions/workflows/test.yaml/badge.svg)

# pandoc-curly-switch
A pandoc Lua filter for referencing metadata values within a document, thus applying variable substitution.

## Referencing variables
Everything defined within the YAML metadata block of a document can be referenced as variable within the document itself. During the conversion, the variables placeholders are replaced with their effective values.

The following syntax is supported for defining variables placeholders:
- `${...}`, the curly brackets syntax
- `!...!`, the exclamation marks syntax

Variable can be referenced using an object-like notation, using any of the supported syntax. For example, having the following metadata block:
```yaml
github:
  organization: https://github.com/cdivita
  url: ${github.organization}/pandoc-curly-switch
filter:
  name: curly-switch
  language: lua
  license:
    type: Apache License, 2.0
  developers:
    - name: Claudio Di Vita
      url: ${github.organization}
```

Therefore, filter's name can be referenced through `${filter.name}` or `!filter.name!`.

Variables are replaced also within metadata block itself and list elements can be referenced using 1-based indexes. For example, `${filter.developers.1.name}` is replaced with `Claudio Di Vita`.

The exclamation marks syntax (`!...!`) is suggested within LaTeX blocks, because it doesn't clash with math mode and doesn't break syntax highlighting tools.