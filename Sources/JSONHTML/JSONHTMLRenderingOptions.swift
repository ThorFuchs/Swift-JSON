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

/// Presentation of the complete standalone JSON document.
public enum JSONHTMLPresentation: String, Sendable {
    /// Expanded highlighted JSON without scripting.
    case formatted
    /// Native disclosures, optional outline and fixed offline enhancement script.
    case interactive
}

/// Additional inclusive ceilings for HTML generation.
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

    /// Maximum container outline entries; overflow fails the whole invocation.
    public var maxOutlineEntries: UInt64 = JSONLimits.balanced[.objectMembers]
    /// Maximum emitted Base64 metadata bytes, including copy JSON and Pointer forms.
    public var maxMetadataBytes: UInt64 = JSONLimits.balanced[.aggregateTextBytes]
    /// Browser search query ceiling in UTF-8 bytes, zero through 65,536.
    ///
    /// This is a query capacity, not a browser instruction or heap quota.
    public var maxSearchQueryBytes: UInt64 = JSONLimits.balanced[.cancellationQuantum]

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
    /// Creates limits with explicit interactive metadata policy.
    /// - Parameters:
    ///   - core: One cumulative owned-operation budget.
    ///   - maxRenderedJSONNodes: Inclusive rendered JSON values.
    ///   - maxDOMNodes: Inclusive conservative DOM upper bound.
    ///   - maxDocumentBytes: Inclusive complete UTF-8 HTML bytes.
    ///   - maxOutlineEntries: Inclusive emitted container outline entries.
    ///   - maxMetadataBytes: Inclusive emitted Base64 metadata bytes.
    ///   - maxSearchQueryBytes: Browser query capacity in UTF-8 bytes, up to 65,536.
    public init(core: JSONLimits = .balanced,
                maxRenderedJSONNodes: UInt64 = JSONLimits.balanced[.nodes],
                maxDOMNodes: UInt64 = JSONLimits.balanced[.nodes],
                maxDocumentBytes: UInt64 = JSONLimits.balanced[.outputBytes],
                maxOutlineEntries: UInt64,
                maxMetadataBytes: UInt64 = JSONLimits.balanced[.aggregateTextBytes],
                maxSearchQueryBytes: UInt64 = JSONLimits.balanced[.cancellationQuantum]) {
        self.init(core: core, maxRenderedJSONNodes: maxRenderedJSONNodes,
                  maxDOMNodes: maxDOMNodes, maxDocumentBytes: maxDocumentBytes)
        self.maxOutlineEntries = maxOutlineEntries; self.maxMetadataBytes = maxMetadataBytes
        self.maxSearchQueryBytes = maxSearchQueryBytes
    }
    package func validate() throws {
        try core.validate()
        guard maxRenderedJSONNodes < UInt64(Int.max), maxDOMNodes < UInt64(Int.max),
              maxDocumentBytes < UInt64(Int.max), maxOutlineEntries < UInt64(Int.max),
              maxMetadataBytes < UInt64(Int.max), maxSearchQueryBytes <= 65_536 else { throw JSONHTMLFailure.invalidConfiguration }
    }
}

/// Configuration for complete highlighted HTML with optional offline interaction.
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

    /// Formatted by default; interactive behavior is explicitly selected.
    public var presentation: JSONHTMLPresentation = .formatted
    /// Containers at levels below this depth start open; root is level zero.
    public var initiallyExpandedDepth: Int = 2
    /// Include containers through this level in the outline; nil disables the outline.
    public var outlineDepth: Int? = 3

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
    /// Creates an explicitly selected presentation.
    ///
    /// Interactive copy/download uses the shared writer's exact preserved bytes.
    /// Search is case-sensitive literal matching over rendered JSON key/value text.
    /// - Parameters:
    ///   - title: Plain escaped title without control characters.
    ///   - theme: Browser color policy.
    ///   - indentation: Indentation units per level, zero through eight.
    ///   - indentationUnit: Literal spaces or tabs.
    ///   - tabWidth: Visual tab width, one through eight.
    ///   - limits: Inclusive core and HTML capacities and work quotas.
    ///   - presentation: Formatted or interactive standalone document.
    ///   - initiallyExpandedDepth: Nonnegative initial disclosure depth; root is level zero.
    ///   - outlineDepth: Nonnegative inclusive container level, or nil to omit the outline.
    public init(title: String = "JSON", theme: JSONHTMLTheme = .automatic,
                indentation: Int = 2, indentationUnit: JSONIndentationUnit = .spaces,
                tabWidth: Int = 4, limits: JSONHTMLLimits = .init(),
                presentation: JSONHTMLPresentation, initiallyExpandedDepth: Int = 2,
                outlineDepth: Int? = 3) {
        self.init(title: title, theme: theme, indentation: indentation,
                  indentationUnit: indentationUnit, tabWidth: tabWidth, limits: limits)
        self.presentation = presentation; self.initiallyExpandedDepth = initiallyExpandedDepth
        self.outlineDepth = outlineDepth
    }
}

/// Stable identifiers for additional HTML capacities.
public enum JSONHTMLResourceMetric: String, Sendable {
    /// JSON values in the selected presentation.
    case renderedJSONNodes
    /// Conservative upper bound of document DOM nodes.
    case domNodes
    /// Complete HTML UTF-8 bytes.
    case documentBytes
    /// Emitted container outline entries.
    case outlineEntries
    /// Emitted Base64 metadata UTF-8 bytes.
    case metadataBytes
}

/// Bounded HTML-specific failures; core resource failures and cancellation propagate unchanged.
public enum JSONHTMLFailure: Error, Sendable, Equatable {
    /// Invalid presentation depth, indentation, tab width, capacity or control-bearing title.
    case invalidConfiguration
    /// An inclusive HTML capacity was exceeded before growth.
    case limitExceeded(JSONHTMLResourceMetric, limit: UInt64, attempted: UInt64)
    /// Checked HTML counter addition overflowed.
    case counterOverflow(JSONHTMLResourceMetric)
}
