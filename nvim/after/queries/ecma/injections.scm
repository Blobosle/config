; extends

; Treat the first template literal passed to a .query method as SQL.
(call_expression
  function: (member_expression
    property: (property_identifier) @_method)
  arguments: (arguments
    . (template_string) @injection.content)
  (#eq? @_method "query")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
  (#set! injection.language "sql"))
