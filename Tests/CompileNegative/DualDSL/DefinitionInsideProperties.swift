import JSONSchemaDSL
let _ = try JSONSchemaDSL.document { Schema.properties { Definition("id") { Schema.type(.string) } } }
