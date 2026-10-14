// SPDX-License-Identifier: Apache-2.0
import JSON

// Closed grammar rejection is deliberately distinct from operational failure.
package enum JSONHTMLPreviewRejection: Error { case syntax, eligibility }
package struct JSONHTMLMathNode {
  package let tag: String
  package let text: String
  package let children: [Int]
}
package struct JSONHTMLMathTree {
  package var nodes: [JSONHTMLMathNode]
  package let root: Int
  package let reservation: UInt64
  package func emit(output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter) throws {
    guard nodes.indices.contains(root) else { throw JSONHTMLFailure.invalidConfiguration }
    for (i, node) in nodes.enumerated() {
      try meter.work()
      switch node.tag {
      case "mi", "mn", "mo":
        guard node.children.isEmpty, !node.text.isEmpty else {
          throw JSONHTMLFailure.invalidConfiguration
        }
      case "mrow":
        guard !node.children.isEmpty, node.text.isEmpty else {
          throw JSONHTMLFailure.invalidConfiguration
        }
      case "msqrt":
        guard node.children.count == 1, node.text.isEmpty else {
          throw JSONHTMLFailure.invalidConfiguration
        }
      case "msup", "msub", "mfrac":
        guard node.children.count == 2, node.text.isEmpty else {
          throw JSONHTMLFailure.invalidConfiguration
        }
      case "msubsup":
        guard node.children.count == 3, node.text.isEmpty else {
          throw JSONHTMLFailure.invalidConfiguration
        }
      default: throw JSONHTMLFailure.invalidConfiguration
      }
      for child in node.children {
        try meter.work()
        guard child >= 0, child < i else { throw JSONHTMLFailure.invalidConfiguration }
      }
    }
    try meter.retain(32)
    try output.addDOM(UInt64(nodes.count) * 2 + 2, meter: &meter)
    try output.append(
      "<math xmlns=\"http://www.w3.org/1998/Math/MathML\" display=\"inline\">", meter: &meter)
    enum Step {
      case node(Int)
      case close(String)
    }
    var stack: [Step] = []
    func push(_ s: Step, _ m: inout JSONWorkMeter) throws {
      try m.retain(32)
      stack.append(s)
    }
    try push(.node(root), &meter)
    while let step = stack.popLast() {
      try meter.release(32)
      try meter.work()
      switch step {
      case .close(let tag): try output.append("</" + tag + ">", meter: &meter)
      case .node(let i):
        let n = nodes[i]
        try output.append("<" + n.tag + ">", meter: &meter)
        if n.children.isEmpty {
          try output.escaped(n.text, meter: &meter)
          try output.append("</" + n.tag + ">", meter: &meter)
        } else {
          try push(.close(n.tag), &meter)
          for child in n.children.reversed() {
            try meter.work()
            try push(.node(child), &meter)
          }
        }
      }
    }
    try output.append("</math>", meter: &meter)
    try meter.release(32)
  }
}
private struct MathFrame {
  enum Kind {
    case expression, group, fractionNumerator
    case fractionDenominator(Int)
    case radical
    case script(Int, Bool, Int?, Int?)
  }
  let kind: Kind
  var items: [Int] = []
}
package enum JSONHTMLMiniMath {
  // Fixed original mappings, not a general macro registry.
  private static let greek: [String: String] = [
    "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "theta": "θ", "lambda": "λ", "mu": "μ",
    "pi": "π", "sigma": "σ", "phi": "φ", "omega": "ω", "Delta": "Δ", "Omega": "Ω",
  ]
  private static let operators: [String: String] = [
    "times": "×", "cdot": "⋅", "pm": "±", "le": "≤", "ge": "≥", "ne": "≠",
  ]
  package static func parse(
    _ source: String, policy: JSONHTMLPreviewPolicy, meter: inout JSONWorkMeter
  ) throws -> JSONHTMLMathTree? {
    let entry = meter.used(.retainedBytes)
    do {
      return try parseBody(source, policy: policy, meter: &meter, entry: entry)
    } catch is JSONHTMLPreviewRejection {
      try meter.release(meter.used(.retainedBytes) - entry)
      return nil
    } catch { throw error }
  }
  private static func parseBody(
    _ source: String, policy: JSONHTMLPreviewPolicy, meter: inout JSONWorkMeter, entry: UInt64
  ) throws -> JSONHTMLMathTree {
    var scalars: [Unicode.Scalar] = []
    var utf8: UInt64 = 0
    for scalar in source.unicodeScalars {
      try meter.work()
      utf8 += UInt64(scalar.utf8.count)
      guard UInt64(scalars.count) < policy.maxMathSourceScalars,
        utf8 <= policy.maxMathSourceUTF8Bytes
      else { throw JSONHTMLPreviewRejection.eligibility }
      try meter.retain(4)
      scalars.append(scalar)
    }
    // One number-token construction plus fixed command/child-call scratch.
    try meter.retain(utf8 + 128)
    var nodes: [JSONHTMLMathNode] = []
    var frames: [MathFrame] = []
    var tokenCount: UInt64 = 0
    var i = 0
    func node(_ tag: String, _ text: String = "", _ children: [Int] = [], _ m: inout JSONWorkMeter)
      throws -> Int
    {
      try m.work()
      guard UInt64(nodes.count) < policy.maxMathNodes else {
        throw JSONHTMLPreviewRejection.eligibility
      }
      try m.retain(64 + UInt64(children.count) * 8 + UInt64(text.utf8.count))
      nodes.append(.init(tag: tag, text: text, children: children))
      return nodes.count - 1
    }
    func push(_ kind: MathFrame.Kind, _ m: inout JSONWorkMeter) throws {
      try m.work()
      guard UInt64(frames.count) < policy.maxMathSyntaxDepth else {
        throw JSONHTMLPreviewRejection.eligibility
      }
      try m.retain(64)
      frames.append(.init(kind: kind))
    }
    func append(_ n: Int, _ m: inout JSONWorkMeter) throws {
      try m.work()
      try m.retain(8)
      frames[frames.count - 1].items.append(n)
    }
    func space(_ m: inout JSONWorkMeter) throws {
      while i < scalars.count && scalars[i] == " " {
        try m.work()
        i += 1
      }
    }
    func token(_ m: inout JSONWorkMeter) throws {
      try m.work()
      guard tokenCount < policy.maxMathTokens else { throw JSONHTMLPreviewRejection.eligibility }
      tokenCount += 1
    }
    func command(_ m: inout JSONWorkMeter) throws -> String {
      try token(&m)
      i += 1
      var text = ""
      while i < scalars.count
        && ((65...90).contains(scalars[i].value) || (97...122).contains(scalars[i].value))
      {
        try m.work()
        text.unicodeScalars.append(scalars[i])
        i += 1
        guard text.utf8.count <= 8 else { throw JSONHTMLPreviewRejection.syntax }
      }
      return text
    }
    func simple(_ m: inout JSONWorkMeter, single: Bool = false) throws -> Int {
      guard i < scalars.count else { throw JSONHTMLPreviewRejection.syntax }
      let c = scalars[i]
      if c == "\\" {
        let name = try command(&m)
        guard let text = greek[name] else { throw JSONHTMLPreviewRejection.syntax }
        return try node("mi", text, [], &m)
      }
      if (48...57).contains(c.value) {
        try token(&m)
        var text = ""
        text.unicodeScalars.append(c)
        i += 1
        if !single {
          while i < scalars.count && (48...57).contains(scalars[i].value) {
            try m.work()
            text.unicodeScalars.append(scalars[i])
            i += 1
          }
          if i < scalars.count && scalars[i] == "." {
            text.append(".")
            i += 1
            let start = i
            while i < scalars.count && (48...57).contains(scalars[i].value) {
              try m.work()
              text.unicodeScalars.append(scalars[i])
              i += 1
            }
            guard i > start else { throw JSONHTMLPreviewRejection.syntax }
          }
        }
        return try node("mn", text, [], &m)
      }
      if (65...90).contains(c.value) || (97...122).contains(c.value)
        || greek.values.contains(String(c))
      {
        try token(&m)
        i += 1
        return try node("mi", String(c), [], &m)
      }
      throw JSONHTMLPreviewRejection.syntax
    }
    func scripted(_ base: Int, _ sub: Int?, _ sup: Int?, _ m: inout JSONWorkMeter) throws -> Int {
      if let sub, let sup { return try node("msubsup", "", [base, sub, sup], &m) }
      if let sub { return try node("msub", "", [base, sub], &m) }
      if let sup { return try node("msup", "", [base, sup], &m) }
      return base
    }
    try push(.expression, &meter)
    var pending: (base: Int, sub: Int?, sup: Int?)?
    while true {
      try meter.work()
      try space(&meter)
      if let p = pending {
        if i < scalars.count && (scalars[i] == "_" || scalars[i] == "^") {
          let isSub = scalars[i] == "_"
          try token(&meter)
          i += 1
          try space(&meter)
          guard isSub ? p.sub == nil : p.sup == nil else { throw JSONHTMLPreviewRejection.syntax }
          if i < scalars.count && scalars[i] == "{" {
            try token(&meter)
            i += 1
            pending = nil
            try push(.script(p.base, isSub, p.sub, p.sup), &meter)
            continue
          }
          let arg = try simple(&meter, single: true)
          // Unbraced alphanumeric runs are ambiguous, never repaired.
          if i < scalars.count {
            let v = scalars[i].value
            if (48...57).contains(v) || (65...90).contains(v) || (97...122).contains(v) {
              throw JSONHTMLPreviewRejection.syntax
            }
          }
          pending = (p.base, isSub ? arg : p.sub, isSub ? p.sup : arg)
          continue
        }
        try append(try scripted(p.base, p.sub, p.sup, &meter), &meter)
        pending = nil
        continue
      }
      if i == scalars.count || scalars[i] == "}" {
        guard let frame = frames.popLast(), !frame.items.isEmpty else {
          throw JSONHTMLPreviewRejection.syntax
        }
        try meter.release(64 + UInt64(frame.items.count) * 8)
        let result =
          frame.items.count == 1 ? frame.items[0] : try node("mrow", "", frame.items, &meter)
        switch frame.kind {
        case .expression:
          guard i == scalars.count, frames.isEmpty else { throw JSONHTMLPreviewRejection.syntax }
          try meter.release(UInt64(scalars.count) * 4 + utf8 + 128)
          return .init(nodes: nodes, root: result, reservation: meter.used(.retainedBytes) - entry)
        case .group:
          guard i < scalars.count else { throw JSONHTMLPreviewRejection.syntax }
          try token(&meter)
          i += 1
          pending = (result, nil, nil)
        case .radical:
          guard i < scalars.count else { throw JSONHTMLPreviewRejection.syntax }
          try token(&meter)
          i += 1
          pending = (try node("msqrt", "", [result], &meter), nil, nil)
        case .fractionNumerator:
          guard i < scalars.count else { throw JSONHTMLPreviewRejection.syntax }
          try token(&meter)
          i += 1
          try space(&meter)
          guard i < scalars.count && scalars[i] == "{" else {
            throw JSONHTMLPreviewRejection.syntax
          }
          try token(&meter)
          i += 1
          try push(.fractionDenominator(result), &meter)
        case .fractionDenominator(let numerator):
          guard i < scalars.count else { throw JSONHTMLPreviewRejection.syntax }
          try token(&meter)
          i += 1
          pending = (try node("mfrac", "", [numerator, result], &meter), nil, nil)
        case .script(let base, let isSub, let sub, let sup):
          guard i < scalars.count else { throw JSONHTMLPreviewRejection.syntax }
          try token(&meter)
          i += 1
          pending = (base, isSub ? result : sub, isSub ? sup : result)
        }
        continue
      }
      let c = scalars[i]
      if c == "{" {
        try token(&meter)
        i += 1
        try push(.group, &meter)
        continue
      }
      if c == "\\" {
        let name = try command(&meter)
        if name == "frac" || name == "sqrt" {
          try space(&meter)
          guard i < scalars.count && scalars[i] == "{" else {
            throw JSONHTMLPreviewRejection.syntax
          }
          try token(&meter)
          i += 1
          try push(name == "frac" ? .fractionNumerator : .radical, &meter)
          continue
        }
        if let g = greek[name] {
          pending = (try node("mi", g, [], &meter), nil, nil)
          continue
        }
        if let op = operators[name] {
          try append(try node("mo", op, [], &meter), &meter)
          continue
        }
        throw JSONHTMLPreviewRejection.syntax
      }
      if "+-=(),/×⋅±≤≥≠".unicodeScalars.contains(c) {
        try token(&meter)
        i += 1
        try append(try node("mo", String(c), [], &meter), &meter)
        continue
      }
      pending = (try simple(&meter), nil, nil)
    }
  }
}
