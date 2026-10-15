// SPDX-License-Identifier: Apache-2.0
import JSON

/// A source value's existing JSON kind; absence is never a value kind.
public enum JSONTraversalKind: Sendable, Hashable, CaseIterable {
    /// An ordered object.
    case object
    /// An array.
    case array
    /// An exact scalar-sequence string.
    case string
    /// An exact bounded decimal.
    case number
    /// A Boolean.
    case boolean
    /// Explicit JSON null.
    case null

    internal init(_ value: JSON) {
        switch value {
        case .object: self = .object
        case .array: self = .array
        case .string: self = .string
        case .number: self = .number
        case .boolean: self = .boolean
        case .null: self = .null
        }
    }
}

/// An intentional synchronous visitor decision, never an operational-error substitute.
public enum JSONTraversalAction: Sendable {
    /// Explore descendants normally.
    case `continue`
    /// Prune only this occurrence's descendants.
    case skipDescendants
    /// End this invocation with explicitly incomplete coverage.
    case stop
}

/// Explicit duplicate/ancestor treatment for an ordered selection of physical roots.
public enum JSONScopeOverlapPolicy: Sendable {
    /// Reject repeated or ancestor/descendant root selections before any visitor call.
    case rejectAmbiguous
    /// Visit each selected subtree independently, including repeated occurrences.
    case orderedOccurrences
    /// Emit a physical typed path at most once; its first examined occurrence wins.
    case uniquePhysicalNodes
}

/// Existing physical subtrees in the captured canonical source, never a synthetic JSON array.
public enum JSONTraversalScope: Sendable {
    /// A strict absolute typed path. An empty path selects the root, of any kind.
    /// - Parameter at: Exact absolute key/index components.
    case subtree(at: [JSONLocationComponent])
    /// Ordered roots, all strictly resolved before traversal. Empty selection is valid.
    /// - Parameters:
    ///   - roots: Ordered absolute typed paths into the captured source.
    ///   - overlap: Explicit rejection, occurrence or exact-path deduplication policy.
    case virtual(roots: [[JSONLocationComponent]], overlap: JSONScopeOverlapPolicy = .rejectAmbiguous)
}

/// DFS emission and exploration policy. Admission always checks the entire captured source.
public struct JSONTraversalOptions: Sendable {
    /// Maximum edges from a selected root, or nil for all admitted descendants.
    public var depthLimit: Int?
    /// Whether to emit each scope root; excluded roots are still visited.
    public var includeScopeRoot: Bool
    /// Kinds to emit, or nil for all six kinds. Filtering never prunes descendants.
    public var emitKinds: Set<JSONTraversalKind>?
    /// Whether emitted hits include coherent original value spans, when available.
    public var includeSourceSpans: Bool

    /// Configures deterministic insertion-order, depth-first preorder traversal.
    /// - Parameters:
    ///   - depthLimit: Nonnegative edge bound; nil still uses finite core limits.
    ///   - includeScopeRoot: Emit roots as well as their descendants.
    ///   - emitKinds: Emission-only filter; an empty set emits no hits.
    ///   - includeSourceSpans: Request metered lookup of original value spans.
    public init(depthLimit: Int? = nil, includeScopeRoot: Bool = true,
                emitKinds: Set<JSONTraversalKind>? = nil, includeSourceSpans: Bool = false) {
        self.depthLimit = depthLimit; self.includeScopeRoot = includeScopeRoot
        self.emitKinds = emitKinds; self.includeSourceSpans = includeSourceSpans
    }
}

/// Metadata for an existing node, without a retained subtree or an escaping cursor.
/// Paths address the traversal's captured document, not an arbitrary replacement root.
public struct JSONTraversalHit: Sendable, Equatable {
    /// Absolute exact key/index components; [] is root and [.key("")] is not.
    public let absoluteLocation: [JSONLocationComponent]
    /// Zero-based root selection index; zero for a physical subtree.
    public let scopeRootIndex: Int
    /// Zero-based visited occurrence ordinal, including filtered nodes.
    public let occurrenceIndex: UInt64
    /// Edges from this occurrence's selected scope root.
    public let relativeDepth: Int
    /// The unchanged source kind.
    public let kind: JSONTraversalKind
    /// An original value span only when requested from a coherent mapped document.
    public let sourceSpan: JSONSourceSpan?
}

/// Structural exploration coverage, independent of emission filters or source-map availability.
public enum JSONTraversalCompletion: Sendable {
    /// All selected descendants were explored, even if filters emitted no hits.
    case complete
    /// A depth policy or visitor pruning omitted descendants.
    case restricted
    /// The visitor explicitly ended the walk; this never establishes global absence.
    case visitorStopped
}

/// Successful exploration facts. Resource failures and cancellation produce no summary.
public struct JSONTraversalSummary: Sendable {
    /// Examined occurrences, including filtered nodes and explicitly repeated roots.
    public internal(set) var visitedCount: UInt64 = 0
    /// Hits handed to the visitor or retained by collect.
    public internal(set) var emittedCount: UInt64 = 0
    /// Maximum relative depth actually examined, zero for an empty selection.
    public internal(set) var maximumDepthVisited: Int = 0
    /// Number of validated root selections.
    public internal(set) var scopeRootCount: Int = 0
    /// Re-examined typed paths omitted under uniquePhysicalNodes; descendants are still explored.
    public internal(set) var deduplicatedCount: UInt64 = 0
    /// Containers whose descendants were explicitly pruned by the visitor.
    public internal(set) var prunedSubtrees: UInt64 = 0
    /// Containers whose descendants were omitted by the depth policy.
    public internal(set) var depthLimitedSubtrees: UInt64 = 0
    /// Whether exploration was complete, policy-restricted or explicitly stopped.
    public internal(set) var completion: JSONTraversalCompletion = .complete
}

/// Bounded metadata records and their independent exploration coverage.
public struct JSONTraversalCollection: Sendable {
    /// Source-ordered hits; no JSON subtrees or generated previews are retained.
    public let nodes: [JSONTraversalHit]
    /// Coverage and observed counts for the same invocation.
    public let summary: JSONTraversalSummary
}

/// A traversal-specific explicit capacity refusal, never a successful truncated result.
public enum JSONTraversalFailure: Error, Sendable, Equatable {
    /// The next collected record would exceed the caller's finite inclusive bound.
    /// - Parameter limit: The nonnegative inclusive maximum record count.
    case collectionLimitExceeded(limit: Int)
    /// Two validated virtual roots are identical or one is an ancestor of the other.
    /// - Parameters:
    ///   - first: The earlier zero-based root selection index.
    ///   - second: The later zero-based root selection index.
    case ambiguousRoots(first: Int, second: Int)
}
