import JSONSchemaDSL
import JSONValueDSL
let _ = try JSONSchemaDSL.document { Field("invalid", "value") }
