_: ''
  (
    DEFAULT=${builtins.toFile "editorconfig" ''
      [[shell]]
      indent_style = space
      indent_size = 2
      charset = utf-8
    ''}
    ${builtins.readFile ./editorConfig}
  )
''
