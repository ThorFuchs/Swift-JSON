// SPDX-License-Identifier: Apache-2.0
import JSON

/// Exact lookup identifiers for prepared artifacts, independent of MIME subtype matching.
public enum JSONExportFormat: String, CaseIterable, Hashable, Sendable {
    /// Strict native JSON; the only importable transfer representation.
    case json
    /// The pretty JSON body, including quotes around string roots.
    case plainText
    /// A safely fenced JSON code block with the unchanged pretty body.
    case markdown
    /// Expanded, highlighted, script-free standalone HTML.
    case html
    /// Styled monospaced rich text with the unchanged pretty JSON body; explicit opt-in.
    case rtf
    /// Explicitly prepared PDF; added only after successful Apple PDF preparation.
    case pdf

    /// The filename extension associated with this exact artifact format.
    public var filenameExtension: String {
        switch self {
        case .json: "json"
        case .plainText: "txt"
        case .markdown: "md"
        case .html: "html"
        case .rtf: "rtf"
        case .pdf: "pdf"
        }
    }
}

/// Finite initial export policy, measured separately from process memory and transport work.
public struct JSONExportLimits: Sendable {
    /// One cumulative meter across admission, formatting, wrapping, HTML and owned copies.
    public var core: JSONLimits
    /// Inclusive bytes in any one complete representation.
    public var maxRepresentationBytes: UInt64
    /// Inclusive sum of all prepared artifacts, including formats hidden by selection.
    public var maxPreparedBytes: UInt64
    /// Inclusive syntax color runs in each RTF artifact, including the initial run.
    public var maxRTFStyleRuns: UInt64
    /// Inclusive UTF-16 code units in the decoded RTF body, including whitespace.
    public var maxRTFUTF16Units: UInt64
    /// Inclusive UTF-8 title bytes before HTML escaping.
    public var maxTitleBytes: UInt64
    /// Inclusive UTF-8 filename stem bytes, excluding the fixed extension.
    public var maxFilenameBytes: UInt64

    /// Creates checked finite export limits. Zero forbids the corresponding usage.
    /// - Parameters:
    ///   - core: Shared cumulative core quotas and capacities.
    ///   - maxRepresentationBytes: Inclusive bytes per artifact.
    ///   - maxPreparedBytes: Inclusive aggregate artifact bytes.
    ///   - maxTitleBytes: Inclusive plain title bytes.
    ///   - maxFilenameBytes: Inclusive filename component bytes.
    ///   - maxRTFStyleRuns: Inclusive RTF color runs; one million by default.
    ///   - maxRTFUTF16Units: Inclusive decoded RTF units; eight million by default.
    public init(core: JSONLimits = .balanced, maxRepresentationBytes: UInt64 = 8_388_608,
                maxPreparedBytes: UInt64 = 16_777_216, maxTitleBytes: UInt64 = 4_096,
                maxFilenameBytes: UInt64 = 128, maxRTFStyleRuns: UInt64 = 1_000_000,
                maxRTFUTF16Units: UInt64 = 8_388_608) {
        self.core = core; self.maxRepresentationBytes = maxRepresentationBytes
        self.maxPreparedBytes = maxPreparedBytes; self.maxTitleBytes = maxTitleBytes
        self.maxFilenameBytes = maxFilenameBytes
        self.maxRTFStyleRuns = maxRTFStyleRuns; self.maxRTFUTF16Units = maxRTFUTF16Units
    }
    package func validate() throws {
        try core.validate()
        guard [maxRepresentationBytes, maxPreparedBytes, maxTitleBytes, maxFilenameBytes, maxRTFStyleRuns, maxRTFUTF16Units]
            .allSatisfy({ $0 < UInt64(Int.max) }) else { throw JSONExportFailure.invalidConfiguration }
    }
}

/// Immutable preparation choices copied into an invocation; no global mutable defaults exist.
public struct JSONExportOptions: Sendable {
    /// Requested complete artifacts; unsupported formats fail the entire preparation.
    public var formats: Set<JSONExportFormat>
    /// Bounded filename component, independent of JSON keys and the title.
    public var filenameStem: String
    /// Bounded plain title used only in HTML presentation.
    public var title: String
    /// Indentation units per level, from zero through eight.
    public var indentation: Int
    /// Literal tabs by default; this does not change JSONWriter defaults.
    public var indentationUnit: JSONIndentationUnit
    /// Visual HTML/RTF tab width, from one through eight; JSON bytes are unaffected.
    public var tabWidth: Int
    /// Deterministic light HTML by default.
    public var theme: JSONHTMLTheme
    /// Compact native JSON only; text and Markdown retain pretty formatting.
    public var compactJSON: Bool
    /// Finite shared core and export capacities.
    public var limits: JSONExportLimits
    /// HTML-specific ceilings; its core limits intersect the export core without resetting work.
    public var htmlLimits: JSONHTMLLimits

    /// Independent HTML shape; defaults to ordered structured forms/cards.
    public var layout: JSONHTMLLayout = .structured
    /// Prepared static HTML defaults to full values.
    public var valueProfile: JSONHTMLValueProfile = .complete
    /// Explicit PDF/print string profile; complete by default.
    public var printValueProfile: JSONHTMLValueProfile = .complete
    /// Closed bounded inline string dialect.
    public var inlineFormatting: JSONHTMLInlineFormatting = .automatic
    /// Enable complete supported sRGB previews.
    public var colorPreviews: Bool = true
    /// Enable declared canonical PNG/JPEG previews.
    public var embeddedImagePreviews: Bool = true
    /// Default inert link policy.
    public var linkActivation: JSONHTMLLinkActivation = .disabled
    /// Explicit typed instance declarations.
    public var previewHints: [JSONHTMLPreviewHint] = []
    /// Caller-translated effective content annotations; independent of schema validity.
    public var effectivePreviewHints: [JSONHTMLPreviewHint] = []
    /// Finite local preview eligibility policy, additional to the cumulative core meter.
    public var previewPolicy: JSONHTMLPreviewPolicy = .init()

    /// Creates preparation options with four native artifacts and one tab per level.
    /// - Parameters:
    ///   - formats: Requested exact artifact identifiers.
    ///   - filenameStem: Safe bounded filename component without separators or controls.
    ///   - title: Plain bounded title without control characters.
    ///   - indentation: Unit count per nesting level, zero through eight.
    ///   - indentationUnit: Literal spaces or tabs.
    ///   - tabWidth: HTML/RTF tab display width, one through eight.
    ///   - theme: HTML color policy.
    ///   - compactJSON: Whether native JSON alone should omit pretty whitespace.
    ///   - limits: Shared core and export limits.
    ///   - htmlLimits: Additional HTML generation limits.
    public init(formats: Set<JSONExportFormat> = [.json, .plainText, .markdown, .html],
                filenameStem: String = "JSON", title: String = "JSON", indentation: Int = 1,
                indentationUnit: JSONIndentationUnit = .tabs, tabWidth: Int = 4,
                theme: JSONHTMLTheme = .light, compactJSON: Bool = false,
                limits: JSONExportLimits = .init(), htmlLimits: JSONHTMLLimits = .init()) {
        self.formats = formats; self.filenameStem = filenameStem; self.title = title
        self.indentation = indentation; self.indentationUnit = indentationUnit; self.tabWidth = tabWidth
        self.theme = theme; self.compactJSON = compactJSON; self.limits = limits; self.htmlLimits = htmlLimits
    }
}

/// Export-specific inclusive capacity identifiers; core failures retain their native resource detail.
public enum JSONExportResourceMetric: String, Sendable {
    /// Bytes in one representation or its construction buffer.
    case representationBytes
    /// Sum of all prepared artifact bytes.
    case preparedBytes
    /// Syntax color runs in one RTF artifact, including the initial run.
    case rtfStyleRuns
    /// UTF-16 code units in the decoded RTF body.
    case rtfUTF16Units
    /// RTF tab position in twips, bounded by the format's signed 32-bit parameter.
    case rtfTabPosition
    /// Plain UTF-8 title bytes.
    case titleBytes
    /// Plain UTF-8 filename component bytes.
    case filenameBytes
}

/// Bounded export failures containing no untrusted text or partial successful document.
public enum JSONExportFailure: Error, Sendable, Equatable {
    /// Empty selection, invalid limits, indentation or unsafe metadata.
    case invalidConfiguration
    /// A reserved or unsupported artifact is unavailable in this implementation.
    case unsupportedFormat(JSONExportFormat)
    /// PDF requires a separately qualified explicit preparation operation.
    case preparationRequired(JSONExportFormat)
    /// Exact artifact lookup or selection requested an absent artifact.
    case unavailableFormat(JSONExportFormat)
    /// An inclusive export ceiling failed before growth.
    case limitExceeded(JSONExportResourceMetric, limit: UInt64, attempted: UInt64)
    /// Checked export counter addition overflowed.
    case counterOverflow(JSONExportResourceMetric)
}
