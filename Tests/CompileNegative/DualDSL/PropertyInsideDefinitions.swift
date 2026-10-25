import JSONSchemaDSL
let _ = try JSONSchemaDSL.document { Schema.definitions { Property("id") { Schema.type(.string) } } }
