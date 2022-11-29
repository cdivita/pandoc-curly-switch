# pandoc-curly-switch
A pandoc Lua filter for referencing metadata values within a document, thus applying variable substitution.

## Referencing variables
Everything defined within the YAML metadata block of a document can be referenced as variable within the document itself. During the conversion, the variables placeholders are replaced with their effective values.

The following syntax is supported for defining variables placeholders:
- `${...}`, the curly brackets syntax
- `!...!`, the exclamation marks syntax

Variable can be referenced using an object-like notation, using any of the supported syntax. For example, having the following metadata block:
```yaml
filter:
  name: curly-switch
  language: lua
  license:
    type: Apache License, 2.0
  developers:
    - name: Claudio Di Vita
      url: https://github.com/cdivita
```

Therefore, filter's name can be referenced through `${filter.name}` or `!filter.name!`.

The exclamation marks syntax (`!...!`) is suggested within LaTeX blocks, because it doesn't clash with math mode and doesn't break syntax highlighting tools.