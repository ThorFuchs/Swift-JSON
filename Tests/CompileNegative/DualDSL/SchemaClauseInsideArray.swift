import JSONSchemaDSL
import JSONValueDSL
let _ = try JSONValueDSL.array { Schema.type(.string) }
