// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONFilterRuntime

/// Inclusive finite limits for compilation and one synchronous execution scope.
///
/// Native JSON limits remain additional ceilings. Work is cumulative across all
/// pulls and provider inputs. Logical retention is not process RSS. Provider
/// callback instructions and already allocated caller values remain caller work.
public struct JSONTransformLimits: Sendable, Equatable {
    /// A transformation-specific capacity or cumulative work counter.
    public enum Metric: String, CaseIterable, Sendable {
        /// UTF-8 query source bytes admitted by compilation.
        case sourceBytes
        /// Tokens admitted by compilation.
        case tokens
        /// Flat compiler nodes.
        case planNodes
        /// Query syntax nesting.
        case depth
        /// Simultaneously live evaluation frames.
        case frames
        /// Simultaneously live variable bindings.
        case bindings
        /// Simultaneously live collection slots.
        case collectionValues
        /// Total admitted root and provider values in an execution.
        case inputValues
        /// Total yielded results in an execution.
        case results
        /// Cumulative owned work, also limited by the native work ceiling.
        case workUnits
        /// Logical live bytes, also limited by the native retention ceiling.
        case retainedBytes

        var runtime: TransformRuntimeMetric {
            switch self {
            case .sourceBytes: .querySourceBytes
            case .tokens: .queryTokens
            case .planNodes: .astNodes
            case .depth: .queryDepth
            case .frames: .runtimeFrames
            case .bindings: .bindings
            case .collectionValues: .collectionValues
            case .inputValues: .totalRecords
            case .results: .totalResults
            case .workUnits: .totalWorkUnits
            case .retainedBytes: .retainedBytes
            }
        }
    }
    var runtime: TransformRuntimeLimits
    /// Native admission, output-value, numeric, cancellation and work ceilings.
    public var json: JSONLimits {
        get { runtime.core }
        set { runtime.core = newValue }
    }
    /// Creates finite policy from an existing native resource profile.
    /// - Parameter profile: The finite default policy to use.
    public init(profile: JSONResourceProfile = .balanced) { runtime = .init(profile: profile) }
    /// Reads or tightens a transform-specific inclusive maximum.
    /// - Parameter metric: The transform counter to configure.
    public subscript(metric: Metric) -> UInt64 {
        get { runtime[metric.runtime] }
        set { runtime[metric.runtime] = newValue }
    }
}
