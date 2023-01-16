![Works with pandoc](https://github.com/cdivita/pandoc-curly-switch/actions/workflows/pandoc.yaml/badge.svg)

# curly-switch
A [pandoc](https://pandoc.org/) [Lua filter](https://pandoc.org/lua-filters.html) for referencing metadata values within a document, thus applying variable substitution.
## Referencing variables
Every document metadata, defined within the [YAML metadata block](https://pandoc.org/MANUAL.html#extension-yaml_metadata_block) or through [--metadata](https://pandoc.org/MANUAL.html#option--metadata)/[--metadata-file](https://pandoc.org/MANUAL.html#option--metadata-file) arguments, can be referenced as variable within the document itself. During the conversion, the variables placeholders are replaced with their effective values.

The following syntax is supported for defining variables placeholders:
- `${...}`, the curly brackets syntax
- `!...!`, the exclamation marks syntax

Variable can be referenced using an object-like notation, using any of the supported syntax. For example, having the following YAML metadata block:
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

The filter's name can be referenced through `${filter.name}` or `!filter.name!`.

Variables are replaced also within metadata block itself and list elements can be referenced using 1-based indexes. For example:
- `${github.url}` is replaced with `https://github.com/cdivita/pandoc-curly-switch`
- `${filter.developers.1.name}` is replaced with `Claudio Di Vita`

The exclamation marks syntax (`!...!`) is suggested within LaTeX blocks, because it doesn't clash with math mode and doesn't break syntax highlighting tools.

## Potential issues with `tex_math_dollars` extension
When using the  the curly brackets syntax (`${...}`) since the [tex_math_dollars](https://pandoc.org/MANUAL.html#extension-tex_math_dollars) extension is enabled by default, based on the expression content issues can be experienced, due to wrong metadata parsing.

To avoid such issues, the following options are available:
- Escape the `$` character with a backslash `\$`: for example, `\${my.variable}`
- Disable the [tex_math_dollars](https://pandoc.org/MANUAL.html#extension-tex_math_dollars) extension using the [-f/--from](https://pandoc.org/MANUAL.html#option--from): `-f markdown-tex_math_dollars`
## Installation
As any pandoc Lua filter, `curly-switch` can be used without special installation, just by passing the respective `.lua` file path to `pandoc` using the `--lua-filter/-L` argument.

User-global installation is possible by placing a filter in within the filters directory of pandoc's user data directory. This allows to use the filters just by using the filename, without having to specify the full file path.

On Mac and Linux, the filter can be installed through the command line using a single instruction:
```
CURLY_SWITCH=curly-switch.lua curl -LSs -o $(pandoc --version | sed -n "s/^.*User data directory:\s*\(\S*\).*$/\1/p")/${CURLY_SWITCH} https://raw.githubusercontent.com/cdivita/pandoc-curly-switch/main/${CURLY_SWITCH}
```