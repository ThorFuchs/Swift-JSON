import JSON
import JSONSchema
import JSONSchemaDSL
import JSONValueDSL
// SPDX-License-Identifier: Apache-2.0
import Testing

@Suite struct StressTypeCheckTests {
    /// Compile-time fixture: 96 heterogeneously placed declarations without
    /// fixed-arity buildBlock overloads. No speed claim without proper profiling.
    @Test func prototypeWideSchemaAndValueBlocks() throws {
        let schema = try JSONSchemaDSL.document {
            Schema.type(.object)
            Schema.properties {
                Property("field001") { Schema.type(.string) }
                Property("field002") { Schema.type(.string) }
                Property("field003") { Schema.type(.string) }
                Property("field004") {
                    Schema.type(.string)
                    Schema.minLength(4)
                }
                Property("field005") { Schema.type(.string) }
                Property("field006") { Schema.type(.string) }
                Property("field007") { Schema.type(.string) }
                Property("field008") {
                    Schema.type(.string)
                    Schema.minLength(1)
                }
                Property("field009") { Schema.type(.string) }
                Property("field010") { Schema.type(.string) }
                Property("field011") { Schema.type(.string) }
                Property("field012") {
                    Schema.type(.string)
                    Schema.minLength(5)
                }
                Property("field013") { Schema.type(.string) }
                Property("field014") { Schema.type(.string) }
                Property("field015") { Schema.type(.string) }
                Property("field016") {
                    Schema.type(.string)
                    Schema.minLength(2)
                }
                Property("field017") { Schema.type(.string) }
                Property("field018") { Schema.type(.string) }
                Property("field019") { Schema.type(.string) }
                Property("field020") {
                    Schema.type(.string)
                    Schema.minLength(6)
                }
                Property("field021") { Schema.type(.string) }
                Property("field022") { Schema.type(.string) }
                Property("field023") { Schema.type(.string) }
                Property("field024") {
                    Schema.type(.string)
                    Schema.minLength(3)
                }
                Property("field025") { Schema.type(.string) }
                Property("field026") { Schema.type(.string) }
                Property("field027") { Schema.type(.string) }
                Property("field028") {
                    Schema.type(.string)
                    Schema.minLength(0)
                }
                Property("field029") { Schema.type(.string) }
                Property("field030") { Schema.type(.string) }
                Property("field031") { Schema.type(.string) }
                Property("field032") {
                    Schema.type(.string)
                    Schema.minLength(4)
                }
                Property("field033") { Schema.type(.string) }
                Property("field034") { Schema.type(.string) }
                Property("field035") { Schema.type(.string) }
                Property("field036") {
                    Schema.type(.string)
                    Schema.minLength(1)
                }
                Property("field037") { Schema.type(.string) }
                Property("field038") { Schema.type(.string) }
                Property("field039") { Schema.type(.string) }
                Property("field040") {
                    Schema.type(.string)
                    Schema.minLength(5)
                }
                Property("field041") { Schema.type(.string) }
                Property("field042") { Schema.type(.string) }
                Property("field043") { Schema.type(.string) }
                Property("field044") {
                    Schema.type(.string)
                    Schema.minLength(2)
                }
                Property("field045") { Schema.type(.string) }
                Property("field046") { Schema.type(.string) }
                Property("field047") { Schema.type(.string) }
                Property("field048") {
                    Schema.type(.string)
                    Schema.minLength(6)
                }
                Property("field049") { Schema.type(.string) }
                Property("field050") { Schema.type(.string) }
                Property("field051") { Schema.type(.string) }
                Property("field052") {
                    Schema.type(.string)
                    Schema.minLength(3)
                }
                Property("field053") { Schema.type(.string) }
                Property("field054") { Schema.type(.string) }
                Property("field055") { Schema.type(.string) }
                Property("field056") {
                    Schema.type(.string)
                    Schema.minLength(0)
                }
                Property("field057") { Schema.type(.string) }
                Property("field058") { Schema.type(.string) }
                Property("field059") { Schema.type(.string) }
                Property("field060") {
                    Schema.type(.string)
                    Schema.minLength(4)
                }
                Property("field061") { Schema.type(.string) }
                Property("field062") { Schema.type(.string) }
                Property("field063") { Schema.type(.string) }
                Property("field064") {
                    Schema.type(.string)
                    Schema.minLength(1)
                }
                Property("field065") { Schema.type(.string) }
                Property("field066") { Schema.type(.string) }
                Property("field067") { Schema.type(.string) }
                Property("field068") {
                    Schema.type(.string)
                    Schema.minLength(5)
                }
                Property("field069") { Schema.type(.string) }
                Property("field070") { Schema.type(.string) }
                Property("field071") { Schema.type(.string) }
                Property("field072") {
                    Schema.type(.string)
                    Schema.minLength(2)
                }
                Property("field073") { Schema.type(.string) }
                Property("field074") { Schema.type(.string) }
                Property("field075") { Schema.type(.string) }
                Property("field076") {
                    Schema.type(.string)
                    Schema.minLength(6)
                }
                Property("field077") { Schema.type(.string) }
                Property("field078") { Schema.type(.string) }
                Property("field079") { Schema.type(.string) }
                Property("field080") {
                    Schema.type(.string)
                    Schema.minLength(3)
                }
                Property("field081") { Schema.type(.string) }
                Property("field082") { Schema.type(.string) }
                Property("field083") { Schema.type(.string) }
                Property("field084") {
                    Schema.type(.string)
                    Schema.minLength(0)
                }
                Property("field085") { Schema.type(.string) }
                Property("field086") { Schema.type(.string) }
                Property("field087") { Schema.type(.string) }
                Property("field088") {
                    Schema.type(.string)
                    Schema.minLength(4)
                }
                Property("field089") { Schema.type(.string) }
                Property("field090") { Schema.type(.string) }
                Property("field091") { Schema.type(.string) }
                Property("field092") {
                    Schema.type(.string)
                    Schema.minLength(1)
                }
                Property("field093") { Schema.type(.string) }
                Property("field094") { Schema.type(.string) }
                Property("field095") { Schema.type(.string) }
                Property("field096") {
                    Schema.type(.string)
                    Schema.minLength(5)
                }
            }
        }
        #expect((schema.raw.objectValue?["properties"]?.objectValue?.members.count) == (96))
        let doc = try JSONValueDSL.object {
            Field("field001", "value1")
            Field("field002", "value2")
            Field("field003", "value3")
            Field("field004", "value4")
            Field("field005", "value5")
            Field("field006", "value6")
            Field("field007", "value7")
            Field("field008", "value8")
            Field("field009", "value9")
            Field("field010", "value10")
            Field("field011", "value11")
            Field("field012", "value12")
            Field("field013", "value13")
            Field("field014", "value14")
            Field("field015", "value15")
            Field("field016", "value16")
            Field("field017", "value17")
            Field("field018", "value18")
            Field("field019", "value19")
            Field("field020", "value20")
            Field("field021", "value21")
            Field("field022", "value22")
            Field("field023", "value23")
            Field("field024", "value24")
            Field("field025", "value25")
            Field("field026", "value26")
            Field("field027", "value27")
            Field("field028", "value28")
            Field("field029", "value29")
            Field("field030", "value30")
            Field("field031", "value31")
            Field("field032", "value32")
            Field("field033", "value33")
            Field("field034", "value34")
            Field("field035", "value35")
            Field("field036", "value36")
            Field("field037", "value37")
            Field("field038", "value38")
            Field("field039", "value39")
            Field("field040", "value40")
            Field("field041", "value41")
            Field("field042", "value42")
            Field("field043", "value43")
            Field("field044", "value44")
            Field("field045", "value45")
            Field("field046", "value46")
            Field("field047", "value47")
            Field("field048", "value48")
            Field("field049", "value49")
            Field("field050", "value50")
            Field("field051", "value51")
            Field("field052", "value52")
            Field("field053", "value53")
            Field("field054", "value54")
            Field("field055", "value55")
            Field("field056", "value56")
            Field("field057", "value57")
            Field("field058", "value58")
            Field("field059", "value59")
            Field("field060", "value60")
            Field("field061", "value61")
            Field("field062", "value62")
            Field("field063", "value63")
            Field("field064", "value64")
        }
        #expect((doc.objectValue?.members.count) == (64))
        let plan = try JSONSchemaCompiler().compile(schema)
        #expect(try JSONSchemaValidator().validate(doc, against: plan).isValid)
        #expect(
            try !JSONSchemaValidator().validate(JSONParser().parse(#"{"field001":1}"#), against: plan).isValid
        )
    }
}
