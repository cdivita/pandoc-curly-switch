---
github:
  organization: https://github.com/cdivita
  url: "${github.organization}/pandoc-curly-switch"
filter:
  name: curly-switch
  language: lua
  license:
    type: Apache License, 2.0
  developers:
    - name: Claudio Di Vita
      url: ${github.organization}
---
# ${filter.name}

- URL: [\${github.url}](${github.url})
- Language: ${filter.language}
- License: ${filter.license.type}
- Developed by: ${filter.developers.1.name}