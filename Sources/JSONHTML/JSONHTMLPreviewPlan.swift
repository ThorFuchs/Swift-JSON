// SPDX-License-Identifier: Apache-2.0
import JSON

package enum JSONHTMLPrimaryPreview {
  case literal
  case inline(JSONHTMLInlinePlan)
  case color(JSONHTMLColor)
  case image(JSONHTMLRaster)
}
package struct JSONHTMLNodePreview {
  let prefix: JSONHTMLStringPrefix?
  let primary: JSONHTMLPrimaryPreview
}
package struct JSONHTMLPreviewIssue {
  let path: [JSONLocationComponent]
  let message: String
}
package struct JSONHTMLPreviewPlan {
  var nodes: [JSONHTMLNodePreview]
  var issues: [JSONHTMLPreviewIssue]
  let media: JSONHTMLMediaLedger
  let reservation: UInt64
  var shortened: Bool
  package static func make(
    _ value: JSON, options: JSONHTMLRenderingOptions, meter: inout JSONWorkMeter
  ) throws -> Self {
    let entry = meter.used(.retainedBytes)
    try options.previewPolicy.validate()
    let explicit = options.previewHints
    let effective = options.effectivePreviewHints
    for tier in [explicit, effective] {
      try meter.work()
      guard UInt64(tier.count) <= options.previewPolicy.maxHintRecords else {
        throw JSONHTMLFailure.invalidConfiguration
      }
      for i in tier.indices {
        try meter.work()
        try meter.require(.pointerTokens, UInt64(tier[i].path.count))
        for j in 0..<i {
          if try JSONHTMLDisplay.equal(tier[i].path, tier[j].path, meter: &meter) {
            throw JSONHTMLFailure.invalidConfiguration
          }
        }
      }
    }
    try meter.retain(UInt64(explicit.count + effective.count))
    var seenExplicit = Array(repeating: false, count: explicit.count)
    var seenEffective = Array(repeating: false, count: effective.count)
    var nodes: [JSONHTMLNodePreview] = []
    var issues: [JSONHTMLPreviewIssue] = []
    var ledger = JSONHTMLMediaLedger()
    var shortened = false
    enum Step {
      case node(JSON, JSONLocationComponent?)
      case end(Bool)
    }
    var steps: [Step] = []
    var path: [JSONLocationComponent] = []
    func push(_ step: Step, _ m: inout JSONWorkMeter) throws {
      try m.retain(JSONLogicalWeights.frame)
      steps.append(step)
    }
    func issue(_ attempted: [JSONLocationComponent], _ message: String, _ m: inout JSONWorkMeter)
      throws
    {
      try m.charge(.issues)
      try m.retain(64 + UInt64(attempted.count) * JSONLogicalWeights.frame)
      issues.append(.init(path: attempted, message: message))
    }
    try push(.node(value, nil), &meter)
    while let step = steps.popLast() {
      try meter.release(JSONLogicalWeights.frame)
      try meter.work()
      switch step {
      case .end(let pop):
        if pop {
          path.removeLast()
          try meter.release(JSONLogicalWeights.frame)
        }
      case .node(let node, let component):
        if let component {
          try meter.retain(JSONLogicalWeights.frame)
          path.append(component)
        }
        var hint: JSONHTMLPreviewHint.Kind?
        for i in explicit.indices {
          if try JSONHTMLDisplay.equal(path, explicit[i].path, meter: &meter) {
            seenExplicit[i] = true
            hint = explicit[i].kind
          }
        }
        for i in effective.indices {
          if try JSONHTMLDisplay.equal(path, effective[i].path, meter: &meter) {
            seenEffective[i] = true
            if hint == nil { hint = effective[i].kind }
          }
        }
        var prefix: JSONHTMLStringPrefix?
        var primary: JSONHTMLPrimaryPreview = .literal
        if case .string(let string) = node {
          prefix = try JSONHTMLDisplay.prefix(string, policy: options.previewPolicy, meter: &meter)
          shortened = shortened || prefix!.shortened
        }
        var hintFailed = false
        switch hint {
        case .literal: break
        case .color(let units, let order):
          if options.colorPreviews {
            let color: JSONHTMLColor?
            if case .string(let string) = node {
              color = try JSONHTMLColor.parse(string, policy: options.previewPolicy, meter: &meter)
            } else {
              color = try JSONHTMLColor.hinted(node, units: units, order: order, meter: &meter)
            }
            if let color { primary = .color(color) } else { hintFailed = true }
          }
        case .embeddedImage(let type):
          if case .string(let string) = node {
            if options.embeddedImagePreviews {
              if let image = try JSONHTMLRasterAdmission.decode(
                string, type: type, policy: options.previewPolicy, ledger: &ledger, meter: &meter)
              {
                primary = .image(image)
              } else {
                hintFailed = true
              }
            }
          } else {
            hintFailed = true
          }
        case .inlineText:
          if let prefix {
            if options.inlineFormatting != .off {
              let inline = try JSONHTMLInlineScanner.scan(
                prefix.source, options: options, ledger: &ledger, meter: &meter)
              if inline.formatted {
                primary = .inline(inline)
              } else {
                try meter.release(inline.reservation)
              }
            }
          } else {
            hintFailed = true
          }
        case nil:
          if case .string(let string) = node {
            if options.colorPreviews,
              let color = try JSONHTMLColor.parse(
                string, policy: options.previewPolicy, meter: &meter)
            {
              primary = .color(color)
            } else if options.embeddedImagePreviews, string.hasPrefix("data:image/") {
              if let image = try JSONHTMLRasterAdmission.decode(
                string, type: nil, policy: options.previewPolicy, ledger: &ledger, meter: &meter)
              {
                primary = .image(image)
              } else {
                try issue(
                  path, "Declared image preview unavailable; original source retained.", &meter)
              }
            } else if options.inlineFormatting == .automatic, let prefix {
              let inline = try JSONHTMLInlineScanner.scan(
                prefix.source, options: options, ledger: &ledger, meter: &meter)
              if inline.formatted {
                primary = .inline(inline)
              } else {
                try meter.release(inline.reservation)
              }
            }
          }
        }
        if hintFailed {
          try issue(
            path,
            "Preview declaration is unavailable or has the wrong value kind; original value retained.",
            &meter)
        }
        try meter.retain(64)
        nodes.append(.init(prefix: prefix, primary: primary))
        try push(.end(component != nil), &meter)
        switch node {
        case .object(let members):
          for member in members.reversed() {
            try meter.work()
            try push(.node(member.value, .key(member.key)), &meter)
          }
        case .array(let values):
          for i in values.indices.reversed() {
            try meter.work()
            try push(.node(values[i], .index(i)), &meter)
          }
        default: break
        }
      }
    }
    for i in explicit.indices {
      try meter.work()
      if !seenExplicit[i] {
        try issue(explicit[i].path, "Preview declaration path is missing.", &meter)
      }
    }
    for i in effective.indices {
      try meter.work()
      if !seenEffective[i] {
        try issue(effective[i].path, "Effective preview declaration path is missing.", &meter)
      }
    }
    try meter.release(UInt64(explicit.count + effective.count))
    return .init(
      nodes: nodes, issues: issues, media: ledger, reservation: meter.used(.retainedBytes) - entry,
      shortened: shortened)
  }
}
