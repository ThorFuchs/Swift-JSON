import Foundation
import JSON
import JSONFilterRuntime
@main struct KernelProbe { static func main() async throws {
 guard Int.bitWidth == 32 else { fatalError("Expected wasm32") }
 let fixture = try JSONParser().parse(Array(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))))
 guard case .object(let object) = fixture, case .array(let rows) = object[JSONKey("cases")], rows.count == 738 else { fatalError("Fixture cardinality") }
 var passed = 0
 for row in rows {
  guard case .object(let item) = row, case .string(let op) = item[JSONKey("op")], case .string(let lhs) = item[JSONKey("lhs")], case .string(let expected) = item[JSONKey("expected")] else { fatalError("Malformed fixture") }
  var context = try CLIJobContext()
  if case .number(let scale) = item[JSONKey("scale")] { context.divisionScale = try scale.integer(as: Int.self, meter: &context.meter) }
  var value: FilterYield
  if case .string(let rhs) = item[JSONKey("rhs")] { value = try ExactDecimal.binary(op, JSONNumber(parsing: lhs), JSONNumber(parsing: rhs), context: &context) }
  else { value = try ExactDecimal.unary(op, JSONNumber(parsing: lhs), context: &context) }
  guard case .number(let actual) = value.value, try actual.compare(to: JSONNumber(parsing: expected), meter: &context.meter) == .orderedSame, actual.originalLexeme == nil else { fatalError("Arithmetic mismatch") }
  if case .number(let rounded) = item[JSONKey("rounded")] { guard context.roundedDivisions == (try rounded.integer(as: UInt64.self, meter: &context.meter)) else { fatalError("Rounding mismatch") } }
  try value.release(context: &context)
  guard context.meter.used(.retainedBytes) == 0 else { fatalError("Ownership mismatch") }
  passed += 1
 }
 var limits = CLILimits(profile: .offline)
 var aggregate = try CLIJobContext(limits: limits)
 try aggregate.charge(.totalInputBytes, UInt64(Int.max) + 1)
 guard aggregate.used(.totalInputBytes) == 2147483648 else { fatalError("Aggregate narrowed") }
 limits[.collectionValues] = UInt64(Int.max)
 do { _ = try CLIJobContext(limits: limits); fatalError("Unsafe capacity") } catch let error as CLIError { guard error.exit == 2 else { throw error } }
 var narrow = try CLIJobContext()
 do { _ = try FilterOperators.apply("*", .string("x"), .number(JSONNumber(parsing: "18446744073709551616")), context: &narrow); fatalError("Unsafe index") } catch let error as CLIError { guard error.exit == 6 else { throw error } }
 try narrow.reclaimValueLeases()
 guard narrow.meter.used(.retainedBytes) == 0 else { fatalError("Narrowing leak") }
 let cancelled = Task {
  var context = try CLIJobContext()
  context.meter.checkpointObserver = { work in if work >= 5000 { withUnsafeCurrentTask { $0?.cancel() } } }
  let number = try JSONNumber(parsing: String(repeating: "9", count: 300))
  var observed = false
  do { _ = try ExactDecimal.binary("*", number, number, context: &context) } catch is CancellationError { observed = true }
  try context.reclaimValueLeases()
  guard observed && context.meter.used(.numericWorkUnits) >= 5000 && context.meter.used(.retainedBytes) == 0 else { fatalError("Cancellation accounting") }
 }
 try await cancelled.value
 print("WASI_BOUNDARIES passed cases=4 int_bits=32")
 print("WASI_KERNEL passed cases=\(passed) int_bits=\(Int.bitWidth)")
} }
