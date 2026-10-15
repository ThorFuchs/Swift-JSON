// SPDX-License-Identifier: Apache-2.0
import JSON

/// Immutable policy accompanying an already-rendered static HTML artifact.
/// Browser fonts/raster readiness is awaited by explicit PDF preparation, not claimed by native admission.
public struct JSONHTMLPreparedPolicy: Sendable {
    /// Native structure used by both the static artifact and its print representation.
    public let layout: JSONHTMLLayout
    /// Main artifact string profile; inspection is explicitly labelled.
    public let valueProfile: JSONHTMLValueProfile
    /// Print/PDF profile retained by the artifact, with complete values by default.
    public let printValueProfile: JSONHTMLValueProfile
    /// Fixed native MathML and system fonts; no downloaded fonts.
    public let fontPolicy: String
    /// PNG/JPEG headers admitted natively; browser decode must complete before PDF capture.
    public let mediaPolicy: String
    package init(options: JSONExportOptions) {
        layout = options.layout
        valueProfile = options.valueProfile
        printValueProfile = options.printValueProfile
        fontPolicy = "System fonts and native MathML Core; await document.fonts.ready"
        mediaPolicy =
            "Offline canonical PNG/JPEG only; await image decode; native admission is not a raster codec"
    }
}
