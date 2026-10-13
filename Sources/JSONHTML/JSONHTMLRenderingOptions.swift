// SPDX-License-Identifier: Apache-2.0
import JSON

/// The color policy for a standalone formatted document.
public enum JSONHTMLTheme: String, Sendable {
    /// Follow the browser's light or dark preference.
    case automatic
    /// Use light colors independently of browser preference.
    case light
    /// Use dark colors independently of browser preference.
    case dark
}

/// Additional inclusive ceilings for formatted HTML generation.
///
/// Defaults reuse the balanced core node and output ceilings as initial finite
/// policy. They are not measured browser heap, CPU or process RSS guarantees.
public struct JSONHTMLLimits: Sendable {
    /// The one cumulative core budget for admission, formatting, HTML and result copying.
    public var core: JSONLimits
    /// Maximum JSON values rendered; keys are not separate values.
    public var maxRenderedJSONNodes: UInt64
    /// Maximum conservative DOM node upper bound, including fixed document structure.
    public var maxDOMNodes: UInt64
    /// Maximum bytes in the complete UTF-8 HTML document.
    public var maxDocumentBytes: UInt64

    /// Creates finite inclusive rendering limits.
    ///
    /// Zero forbids use. Values must fit supported Int capacity at operation entry.
    /// - Parameters:
    ///   - core: Shared core capacities and cumulative work quotas.
    ///   - maxRenderedJSONNodes: Inclusive count of rendered JSON values.
    ///   - maxDOMNodes: Inclusive conservative DOM node upper bound.
    ///   - maxDocumentBytes: Inclusive complete HTML byte ceiling.
    public init(core: JSONLimits = .balanced,
                maxRenderedJSONNodes: UInt64 = JSONLimits.balanced[.nodes],
                maxDOMNodes: UInt64 = JSONLimits.balanced[.nodes],
                maxDocumentBytes: UInt64 = JSONLimits.balanced[.outputBytes]) {
        self.core = core
        self.maxRenderedJSONNodes = maxRenderedJSONNodes
        self.maxDOMNodes = maxDOMNodes
        self.maxDocumentBytes = maxDocumentBytes
    }
    package func validate() throws {
        try core.validate()
        guard maxRenderedJSONNodes < UInt64(Int.max), maxDOMNodes < UInt64(Int.max),
              maxDocumentBytes < UInt64(Int.max) else { throw JSONHTMLFailure.invalidConfiguration }
    }
}

/// Immutable-facade configuration for expanded, highlighted, script-free HTML.
public struct JSONHTMLRenderingOptions: Sendable {
    /// Plain document title; control characters are rejected and HTML is escaped.
    public var title: String
    /// Automatic, light or dark color policy.
    public var theme: JSONHTMLTheme
    /// Indentation units per level, from zero through eight.
    public var indentation: Int
    /// Literal space or horizontal-tab indentation units.
    public var indentationUnit: JSONIndentationUnit
    /// Browser display width of a tab, from one through eight; JSON bytes do not change.
    public var tabWidth: Int
    /// Finite shared core and HTML capacities.
    public var limits: JSONHTMLLimits

    /// Creates the formatted-rendering configuration.
    ///
    /// Insertion order and preserved numeric lexemes are always used. Constructed
    /// numbers without a source lexeme use exact normalized decimal spelling.
    /// - Parameters:
    ///   - title: Escaped plain title, also shown above the complete JSON body.
    ///   - theme: Browser color policy.
    ///   - indentation: Indentation unit count per nesting level, zero through eight.
    ///   - indentationUnit: Space units by default, or literal tabs.
    ///   - tabWidth: Visual tab width, one through eight.
    ///   - limits: Inclusive core and HTML capacities and work quotas.
    public init(title: String = "JSON", theme: JSONHTMLTheme = .automatic,
                indentation: Int = 2, indentationUnit: JSONIndentationUnit = .spaces,
                tabWidth: Int = 4, limits: JSONHTMLLimits = .init()) {
        self.title = title; self.theme = theme; self.indentation = indentation
        self.indentationUnit = indentationUnit; self.tabWidth = tabWidth; self.limits = limits
    }
}

/// Stable identifiers for the three additional HTML capacities.
public enum JSONHTMLResourceMetric: String, Sendable {
    /// JSON values in the formatted body.
    case renderedJSONNodes
    /// Conservative upper bound of document DOM nodes.
    case domNodes
    /// Complete HTML UTF-8 bytes.
    case documentBytes
}

/// Bounded HTML-specific failures; core resource failures and cancellation propagate unchanged.
public enum JSONHTMLFailure: Error, Sendable, Equatable {
    /// Invalid indentation, tab width, capacity or control-bearing title.
    case invalidConfiguration
    /// An inclusive HTML capacity was exceeded before growth.
    case limitExceeded(JSONHTMLResourceMetric, limit: UInt64, attempted: UInt64)
    /// Checked HTML counter addition overflowed.
    case counterOverflow(JSONHTMLResourceMetric)
}
