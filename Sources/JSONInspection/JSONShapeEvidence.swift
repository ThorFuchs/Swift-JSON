// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Deterministic row sampling, independent of mandatory full-source admission.
public enum JSONShapeSampling: Sendable {
    /// Examine every existing row.
    case complete
    /// Examine at most the first nonnegative number of rows, in array order.
    /// - Parameter maximumRows: Inclusive sample bound; zero establishes no positive trait.
    case prefix(maximumRows: Int)
}

/// Observed row coverage; this never certifies schema or descendant homogeneity.
public enum JSONShapeRowCoverage: Sendable, Equatable {
    /// All array rows were examined, including a genuinely empty array.
    case complete
    /// Only the stated prefix was examined; no assertion describes its suffix.
    /// - Parameters:
    ///   - examined: Number of observed rows.
    ///   - total: Number of rows in the admitted selected array.
    case prefix(examined: Int, total: Int)
}

/// Fixed six-kind counts. Missing is absence, never a seventh JSON value kind.
public struct JSONShapeKindCounts: Sendable, Equatable {
    /// Object values observed.
    public internal(set) var objects: UInt64 = 0
    /// Array values observed.
    public internal(set) var arrays: UInt64 = 0
    /// Scalar-sequence strings observed.
    public internal(set) var strings: UInt64 = 0
    /// Exact decimal values observed, without binary conversion.
    public internal(set) var numbers: UInt64 = 0
    /// Boolean values observed.
    public internal(set) var booleans: UInt64 = 0
    /// Explicit null values observed.
    public internal(set) var nulls: UInt64 = 0

    /// Returns a fixed kind's observed count.
    /// - Parameter kind: One of the six canonical JSON kinds.
    public subscript(kind: JSONTraversalKind) -> UInt64 {
        switch kind {
        case .object: objects; case .array: arrays; case .string: strings
        case .number: numbers; case .boolean: booleans; case .null: nulls
        }
    }
    internal mutating func record(_ value: JSON) {
        switch value {
        case .object: objects += 1; case .array: arrays += 1; case .string: strings += 1
        case .number: numbers += 1; case .boolean: booleans += 1; case .null: nulls += 1
        }
    }
}

/// An exact column seen in sampled object rows, in first-encounter insertion order.
public struct JSONColumnObservation: Sendable {
    /// Decoded scalar identity; canonical-equivalent spellings remain separate keys.
    public let key: JSONKey
    /// Zero-based array row where this key first appeared.
    public let firstRow: Int
    /// Observed object rows containing this key, including explicit null.
    public internal(set) var present: UInt64 = 0
    /// Present cells whose value is explicit JSON null.
    public internal(set) var explicitNull: UInt64 = 0
    /// Observed object rows lacking this key; nonobject rows are excluded.
    public internal(set) var missing: UInt64 = 0
    /// Kinds of present canonical cells; missing cells contribute no kind.
    public internal(set) var kinds = JSONShapeKindCounts()
}

/// Factual evidence about examined rows of one existing canonical array.
/// Prefix traits describe the prefix only. No field certifies a table, numeric
/// matrix, JSON Schema verdict, or unexamined suffix.
public struct JSONShapeArrayEvidence: Sendable {
    /// Absolute typed location of the selected array in the captured document.
    public let sourceSelection: [JSONLocationComponent]
    /// Coherent original selected-array span when requested and available.
    public let sourceSpan: JSONSourceSpan?
    /// True on success: the entire captured root/source/map was admitted once.
    public let sourceAdmissionComplete: Bool
    /// Traversal coverage, separate from row coverage; row descendants are omitted.
    public let traversal: JSONTraversalSummary
    /// Existing number of rows, known from the admitted array.
    public let totalRows: Int
    /// Rows actually examined in increasing index order.
    public let examinedRows: Int
    /// Full or intentionally prefix-scoped row evidence.
    public let rowCoverage: JSONShapeRowCoverage
    /// Kinds of examined rows, without coercion.
    public let rowKinds: JSONShapeKindCounts
    /// Number of examined object rows; the column missing-count denominator.
    public let observedObjectRows: UInt64
    /// Number of examined scalar, null or array rows.
    public let observedNonObjectRows: UInt64
    /// Exact columns in first-seen order across examined object rows.
    public let firstSeenColumns: [JSONColumnObservation]
    /// Nil for no evidence; otherwise whether all examined rows are objects.
    public let observedAllObjects: Bool?
    /// One shared observed row kind, or nil for empty/mixed evidence.
    public let observedUniformRowKind: JSONTraversalKind?
    /// Minimum through maximum lengths among examined array rows, if any.
    public let observedArrayLengthRange: ClosedRange<Int>?
    /// Common width only when every examined row is an array of that length.
    /// This says nothing about cell kinds, numeric conversion or an unseen suffix.
    public let observedRectangularArrayWidth: Int?
}

/// An explicit inspection capacity refusal, never successful partial evidence.
public enum JSONShapeInspectionFailure: Error, Sendable, Equatable {
    /// The next first-seen key would exceed the inclusive column bound.
    /// - Parameter limit: Configured nonnegative maximum column count.
    case columnLimitExceeded(limit: Int)
}
