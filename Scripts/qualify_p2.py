#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Package-internal runtime proof; public types promoted, reducer/accounting storage remains hidden."""
import qualify_p2_borrowing as gate

gate.TARGET = 'JSONInspection'
gate.MODULES = ['JSON', 'JSONNavigation', 'JSONInspection']
gate.CHECK_PREFIX = 'P2_PRIVATE_CHECK'
gate.RUNTIME_LINE = 'P2_PRIVATE_RUNTIME passed cases=6'
gate.SUMMARY = 'P2_ISOLATION {status} configurations=2 consumer_cases=6 negative=12'
gate.CHECKS = {'set-exact','matrix-exact','zero-shape','typed-refusal','one-admission','independent-read'}
gate.NEGATIVES = {
 'external-set-reducer': ('let x = StructuralSetReducer.self', "cannot find 'StructuralSetReducer' in scope", True),
 'external-matrix-reducer': ('let x = NumericMatrixReducer.self', "cannot find 'NumericMatrixReducer' in scope", True),
 'external-accounting': ('let x = P2Accounting.self', "cannot find 'P2Accounting' in scope", True),
 'set-constructor': ('func illegal() { _ = JSONStructuralSetProjection.init }', "initializer is inaccessible due to 'fileprivate' protection level", False),
 'matrix-constructor': ('func illegal() { _ = JSONNumericMatrixProjection.init }', "initializer is inaccessible due to 'fileprivate' protection level", False),
 'matrix-mutation': ('func illegal(_ v: JSONNumericMatrixProjection) { var copy = v; copy.rowCount = 9 }', "cannot assign to property: 'rowCount' is a get-only property", False)
}
gate.POSITIVE = r'''import Foundation
import JSON
import JSONNavigation
import JSONInspection
@main struct P2PrivateConsumer {
 static func check(_ ok:Bool) { precondition(ok) }
 static func pass(_ name:String) { print("P2_PRIVATE_CHECK \(name) passed") }
 static func main() throws {
  let document=try JSONParser().parseDocument(Data(#"{"s":[0.1,0.10,"é","e\u0301"],"m":[[0.10,9007199254740993]],"empty":[[],[]]}"#.utf8))
  let set=try JSONStructuralSetProjection.build(document:document,at:[.key("s")])
  check(set.result.representativeIndices == [0,2,3]);pass("set-exact")
  let matrix=try JSONNumericMatrixProjection.build(document:document,at:[.key("m")])
  check(matrix.result.transposed().rowCount==2 && matrix.result.transposed().columnCount==1)
  check(try matrix.result.element(row:0,column:1).result.originalLexeme=="9007199254740993")
  check(try matrix.result.transposed().element(row:0,column:0).result.originalLexeme=="0.10");pass("matrix-exact")
  let empty=try JSONNumericMatrixProjection.build(document:document,at:[.key("empty")]).result.transposed()
  check(empty.rowCount==0 && empty.columnCount==2);pass("zero-shape")
  do { _=try matrix.result.element(row:-1,column:0);preconditionFailure() }
  catch JSONP2ProjectionFailure.rowOutOfBounds(-1) { }
  do { _=try JSONNumericMatrixProjection.build(document:document,at:[.index(0)]);preconditionFailure() }
  catch let e as JSONAccessFailure { check(e.path == [.index(0)]) };pass("typed-refusal")
  let admission=try JSONReadScope(document,limits:.balanced)
  let nodes=try admission.check().meter.used(.nodes);admission.invalidate()
  check(set.statistics[.nodes]==nodes && matrix.statistics[.nodes]==nodes);pass("one-admission")
  let read=try matrix.result.element(row:0,column:0)
  check(read.statistics[.nodes]==nodes && read.statistics[.retainedBytes]==0)
  var none=JSONLimits.balanced;none[.nodes]=0
  do { _=try matrix.result.element(row:0,column:0,limits:none);preconditionFailure() }
  catch let e as JSONFailure { check(e.resource?.metric == .nodes) }
  check(try matrix.result.element(row:0,column:0).result==read.result);pass("independent-read")
  print("P2_PRIVATE_RUNTIME passed cases=6")
 }
}
'''
if __name__ == '__main__': raise SystemExit(gate.main())
