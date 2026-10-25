import JSONSchemaDSL
import JSONValueDSL
let _ = try JSONValueDSL.object { Element("not-an-object-field") }
