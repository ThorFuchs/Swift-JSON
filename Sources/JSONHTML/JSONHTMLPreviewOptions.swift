// SPDX-License-Identifier: Apache-2.0
import JSON

/// Independent document shape; changing it never changes exact JSON bytes.
public enum JSONHTMLLayout: String, Sendable {
  /// Ordered forms, record cards and scalar lists.
  case structured
  /// Full exact highlighted JSON syntax.
  case syntax
}
/// String presentation; both profiles retain full exact source.
public enum JSONHTMLValueProfile: String, Sendable {
  /// Labelled bounded prefixes with native original-value disclosure.
  case inspection
  /// Full expanded original strings, with optional derived previews alongside.
  case complete
}
/// The closed inline dialect applied to string previews.
public enum JSONHTMLInlineFormatting: String, Sendable {
  /// Literal strings only.
  case off
  /// Apply only to explicitly or effectively hinted inline text.
  case declared
  /// Apply to bounded string prefixes after specialized preview resolution.
  case automatic
}
/// Whether validated inline link destinations can be activated by a user.
public enum JSONHTMLLinkActivation: String, Sendable {
  /// Destinations remain inert text; the default.
  case disabled
  /// Explicitly allow absolute credential-free HTTP/HTTPS user navigation.
  case httpAndHTTPS
}
/// Explicit units for derived color channels, independent of JSON arithmetic.
public enum JSONHTMLColorUnits: String, Sendable {
  /// Integral RGB channels from zero through 255; alpha remains zero through one.
  case integer8
  /// Exact channels from zero through one; appearance rounds to nearest 8-bit channel.
  case normalized
}
/// Explicit channel sequence for an array or named r/g/b/a object.
public enum JSONHTMLColorOrder: String, Sendable {
  /// Three r/g/b channels.
  case rgb
  /// Four r/g/b/a channels.
  case rgba
}
/// The only declared raster media types admitted by the native header pipeline.
public enum JSONHTMLRasterMediaType: String, Sendable {
  /// A signature/header-admitted PNG; no animation claim.
  case png = "image/png"
  /// A signature/header-admitted JPEG; decoding remains browser work.
  case jpeg = "image/jpeg"
}
/// A closed caller declaration at an exact typed instance location.
public struct JSONHTMLPreviewHint: Sendable {
  /// Supported declaration kinds; no callback or arbitrary markup is accepted.
  public enum Kind: Sendable {
    /// Suppress all inference at this node.
    case literal
    /// Apply the bounded inline text dialect.
    case inlineText
    /// Explicit units and channel order; strings still use the complete sRGB grammar.
    /// - Parameters:
    ///   - units: Exact integer8 or normalized interpretation before appearance conversion.
    ///   - order: Required r/g/b or r/g/b/a field order.
    case color(units: JSONHTMLColorUnits, order: JSONHTMLColorOrder)
    /// Declare a bare canonical Base64 string with an allowlisted media type.
    case embeddedImage(JSONHTMLRasterMediaType)
  }
  /// Keys and indices retain distinct scalar identity.
  public let path: [JSONLocationComponent]
  /// Closed declaration; annotation intent is not a schema verdict or codec proof.
  public let kind: Kind
  /// Creates a declaration without traversing or retaining a source document.
  /// - Parameters:
  ///   - path: Exact typed instance location.
  ///   - kind: Closed preview declaration.
  public init(path: [JSONLocationComponent], kind: Kind) {
    self.path = path
    self.kind = kind
  }
}
/// Finite preview eligibility ceilings, additional to unchanged global core/HTML limits.
///
/// These initial policies are not raster decoding, browser instruction or RSS caps.
/// Local ineligibility preserves source; actual enclosing exhaustion is terminal.
public struct JSONHTMLPreviewPolicy: Sendable {
  /// Decoded source scalars in an inspection prefix.
  public var maxSourceScalars: UInt64 = 512
  /// UTF-8 bytes in that prefix.
  public var maxPrefixUTF8Bytes: UInt64 = 2048
  /// Reversible display scalars, excluding quotation/status chrome.
  public var maxEscapedDisplayScalars: UInt64 = 512
  /// Inline delimiter stack depth.
  public var maxInlineNesting: UInt64 = 8
  /// Inline staged token count.
  public var maxInlineTokens: UInt64 = 1024
  /// Decoded inline destination UTF-8 bytes.
  public var maxDestinationUTF8Bytes: UInt64 = 2048
  /// Inline image alternative text scalars.
  public var maxAltScalars: UInt64 = 128
  /// Math candidate source scalars.
  public var maxMathSourceScalars: UInt64 = 256
  /// Math candidate UTF-8 bytes.
  public var maxMathSourceUTF8Bytes: UInt64 = 1024
  /// Math syntax stack depth.
  public var maxMathSyntaxDepth: UInt64 = 16
  /// Math descriptor nodes per candidate.
  public var maxMathNodes: UInt64 = 256
  /// Math tokens per candidate.
  public var maxMathTokens: UInt64 = 512
  /// Declared encoded raster candidate bytes.
  public var maxEncodedImageBytes: UInt64 = 3_145_728
  /// Decoded bytes per image.
  public var maxDecodedImageBytes: UInt64 = 2_097_152
  /// Aggregate admitted decoded raster bytes across unique previews.
  public var maxAggregateDecodedImageBytes: UInt64 = 8_388_608
  /// Raster width in pixels.
  public var maxImageWidth: UInt64 = 2048
  /// Raster height in pixels.
  public var maxImageHeight: UInt64 = 2048
  /// Checked raster width times height.
  public var maxImagePixels: UInt64 = 4_194_304
  /// Maximum native header bytes examined per candidate.
  public var maxImageHeaderBytes: UInt64 = 262_144
  /// Unique admitted raster previews.
  public var maxImagePreviews: UInt64 = 64
  /// Caller declaration records per hint tier.
  public var maxHintRecords: UInt64 = 1024
  /// Complete color candidate UTF-8 bytes.
  public var maxColorCandidateBytes: UInt64 = 256
  /// Creates the initial finite policy; mutate specific ceilings before rendering.
  public init() {}
  package func validate() throws {
    let values = [
      maxSourceScalars, maxPrefixUTF8Bytes, maxEscapedDisplayScalars, maxInlineNesting,
      maxInlineTokens,
      maxDestinationUTF8Bytes, maxAltScalars, maxMathSourceScalars, maxMathSourceUTF8Bytes,
      maxMathSyntaxDepth,
      maxMathNodes, maxMathTokens, maxEncodedImageBytes, maxDecodedImageBytes,
      maxAggregateDecodedImageBytes,
      maxImageWidth, maxImageHeight, maxImagePixels, maxImageHeaderBytes, maxImagePreviews,
      maxHintRecords, maxColorCandidateBytes,
    ]
    guard values.allSatisfy({ $0 < UInt64(Int.max) }) else {
      throw JSONHTMLFailure.invalidConfiguration
    }
  }
}
