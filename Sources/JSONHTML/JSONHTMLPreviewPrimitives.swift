// SPDX-License-Identifier: Apache-2.0
import JSON

package struct JSONHTMLStringPrefix {
  package let source: String
  package let shortened: Bool
  package let scalars: UInt64
  package let displayScalars: UInt64
  package let reservation: UInt64
}
package enum JSONHTMLDisplay {
  private static let hex = Array("0123456789abcdef".utf8)
  package static func protected(_ c: Unicode.Scalar) -> Bool {
    let v = c.value
    return c.properties.generalCategory == .format || v <= 31 || (127...159).contains(v)
      || [0xad, 0x61c, 0xfeff, 0xe0001].contains(v)
      || (0x200b...0x200f).contains(v) || (0x2028...0x202e).contains(v)
      || (0x2060...0x206f).contains(v) || (0xfff9...0xfffb).contains(v)
      || (0xe0020...0xe007f).contains(v)
  }
  package static func units(_ c: Unicode.Scalar) -> UInt64 {
    if protected(c) { return c.value > 0xffff ? 12 : 6 }
    return c == "\"" || c == "\\" ? 2 : 1
  }
  package static func prefix(
    _ text: String, policy: JSONHTMLPreviewPolicy, meter: inout JSONWorkMeter
  ) throws -> JSONHTMLStringPrefix {
    var iterator = text.unicodeScalars.makeIterator()
    var source = ""
    var count: UInt64 = 0
    var bytes: UInt64 = 0
    var display: UInt64 = 0
    while let c = iterator.next() {
      try meter.work()
      let width = UInt64(c.utf8.count)
      let cost = units(c)
      if count >= policy.maxSourceScalars || bytes + width > policy.maxPrefixUTF8Bytes
        || display + cost > policy.maxEscapedDisplayScalars
      {
        return .init(
          source: source, shortened: true, scalars: count, displayScalars: display,
          reservation: bytes)
      }
      for _ in c.utf8 {
        try meter.work()
        try meter.retain(1)
      }
      source.unicodeScalars.append(c)
      count += 1
      bytes += width
      display += cost
    }
    return .init(
      source: source, shortened: false, scalars: count, displayScalars: display, reservation: bytes)
  }
  package static func text(
    _ text: String, quoted: Bool, output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter
  ) throws {
    if quoted { try output.escaped(34, meter: &meter) }
    func escape(_ value: UInt32, _ out: inout JSONHTMLDocumentBuffer, _ m: inout JSONWorkMeter)
      throws
    {
      try out.append("\\u", meter: &m)
      for shift in [12, 8, 4, 0] {
        try m.work()
        try out.appendByte(hex[Int(value >> shift & 15)], meter: &m)
      }
    }
    for c in text.unicodeScalars {
      try meter.work()
      if protected(c) {
        if c.value <= 0xffff {
          try escape(c.value, &output, &meter)
        } else {
          let v = c.value - 0x10000
          try escape(0xd800 + (v >> 10), &output, &meter)
          try escape(0xdc00 + (v & 1023), &output, &meter)
        }
      } else if c == "\"" || c == "\\" {
        try output.appendByte(92, meter: &meter)
        for b in c.utf8 { try output.escaped(b, meter: &meter) }
      } else {
        for b in c.utf8 { try output.escaped(b, meter: &meter) }
      }
    }
    if quoted { try output.escaped(34, meter: &meter) }
  }
  package static func equal(
    _ lhs: [JSONLocationComponent], _ rhs: [JSONLocationComponent], meter: inout JSONWorkMeter
  ) throws -> Bool {
    try meter.work()
    guard lhs.count == rhs.count else { return false }
    for (a, b) in zip(lhs, rhs) {
      try meter.work()
      switch (a, b) {
      case (.index(let x), .index(let y)): if x != y { return false }
      case (.key(let x), .key(let y)):
        var l = x.string.utf8.makeIterator()
        var r = y.string.utf8.makeIterator()
        while true {
          try meter.work()
          let a = l.next()
          let b = r.next()
          if a != b { return false }
          if a == nil { break }
        }
      default: return false
      }
    }
    return true
  }
}
package struct JSONHTMLColor {
  package let r: UInt8, g: UInt8, b: UInt8, a: Double
  package let derived: Bool
  package func emit(
    ordinal: UInt64, namespace: String, label: JSONHTMLStringPrefix?,
    output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter
  ) throws {
    guard a.isFinite, a >= 0, a <= 1 else { throw JSONHTMLFailure.invalidConfiguration }
    try meter.retain(64)
    try output.addDOM(18, meter: &meter)
    try output.append(
      "<svg class=\"color-swatch\" viewBox=\"0 0 120 48\" role=\"img\" aria-label=\"sRGB color preview\"><defs><pattern id=\"jh-check-",
      meter: &meter)
    try output.append(namespace, meter: &meter)
    try output.decimal(ordinal, meter: &meter)
    try output.append(
      "\" width=\"12\" height=\"12\" patternUnits=\"userSpaceOnUse\"><rect width=\"12\" height=\"12\" fill=\"#ffffff\"/><path d=\"M0 0h6v6H0zM6 6h6v6H6z\" fill=\"#bbbbbb\"/></pattern></defs><rect width=\"120\" height=\"48\" fill=\"url(#jh-check-",
      meter: &meter)
    try output.append(namespace, meter: &meter)
    try output.decimal(ordinal, meter: &meter)
    try output.append(")\"/><rect width=\"120\" height=\"48\" fill=\"rgb(", meter: &meter)
    try output.decimal(UInt64(r), meter: &meter)
    try output.append(",", meter: &meter)
    try output.decimal(UInt64(g), meter: &meter)
    try output.append(",", meter: &meter)
    try output.decimal(UInt64(b), meter: &meter)
    try output.append(")\" fill-opacity=\"", meter: &meter)
    try meter.work(32)
    try output.append(String(a), meter: &meter)
    try output.append(
      "\"/><rect x=\"6\" y=\"28\" width=\"108\" height=\"16\" rx=\"3\" fill=\"#ffffff\"/><text x=\"60\" y=\"39\" text-anchor=\"middle\" fill=\"#111111\" font-size=\"9\" font-family=\"ui-monospace,monospace\">",
      meter: &meter)
    if !derived, let label {
      try output.escaped(label.source, meter: &meter)
      if label.shortened { try output.append(" (preview)", meter: &meter) }
    } else {
      try output.append("Derived #", meter: &meter)
      for v in [r, g, b, UInt8((a * 255).rounded())] {
        for n in [v >> 4, v & 15] {
          try meter.work()
          try output.appendByte(n < 10 ? n + 48 : n + 87, meter: &meter)
        }
      }
    }
    try output.append("</text></svg><span class=\"preview-kind\">", meter: &meter)
    try output.append(derived ? "Derived sRGB channels: " : "sRGB channels: ", meter: &meter)
    for (i, v) in [r, g, b].enumerated() {
      if i > 0 { try output.append(", ", meter: &meter) }
      try output.decimal(UInt64(v), meter: &meter)
    }
    try output.append("; alpha ", meter: &meter)
    try output.append(String(a), meter: &meter)
    try output.append("</span>", meter: &meter)
    try meter.release(64)
  }
  package static func parse(
    _ source: String, policy: JSONHTMLPreviewPolicy, meter: inout JSONWorkMeter
  ) throws -> Self? {
    var bytes: [UInt8] = []
    for b in source.utf8 {
      try meter.work()
      guard UInt64(bytes.count) < policy.maxColorCandidateBytes, b >= 32, b < 127 else {
        try meter.release(UInt64(bytes.count))
        return nil
      }
      try meter.retain(1)
      bytes.append(b)
    }
    try meter.retain(128)
    let result = try parseBytes(bytes, meter: &meter)
    try meter.release(128 + UInt64(bytes.count))
    return result
  }
  private static func parseBytes(_ bytes: [UInt8], meter: inout JSONWorkMeter) throws -> Self? {
    func nibble(_ x: UInt8) -> UInt8? {
      switch x {
      case 48...57: return x - 48
      case 65...70: return x - 55
      case 97...102: return x - 87
      default: return nil
      }
    }
    if bytes.first == 35 {
      guard [4, 5, 7, 9].contains(bytes.count) else { return nil }
      var values: [UInt8] = []
      let short = bytes.count < 6
      var i = 1
      while i < bytes.count {
        try meter.work()
        guard let n = nibble(bytes[i]) else { return nil }
        if short {
          values.append(n * 17)
          i += 1
        } else {
          guard let m = nibble(bytes[i + 1]) else { return nil }
          values.append(n * 16 + m)
          i += 2
        }
      }
      return .init(
        r: values[0], g: values[1], b: values[2],
        a: values.count == 4 ? Double(values[3]) / 255 : 1, derived: false)
    }
    let rgba = bytes.starts(with: Array("rgba(".utf8))
    let rgb = bytes.starts(with: Array("rgb(".utf8))
    guard rgba || rgb else { return nil }
    var i = rgba ? 5 : 4
    var values: [Double] = []
    for channel in 0..<(rgba ? 4 : 3) {
      while i < bytes.count && bytes[i] == 32 {
        try meter.work()
        i += 1
      }
      var value: UInt64 = 0
      var digits = 0
      while i < bytes.count && (48...57).contains(bytes[i]) {
        try meter.work()
        guard value <= 255 else { return nil }
        value = value * 10 + UInt64(bytes[i] - 48)
        digits += 1
        i += 1
      }
      guard digits > 0 || (channel == 3 && i < bytes.count && bytes[i] == 46) else { return nil }
      var projected = Double(value)
      if channel == 3 && i < bytes.count && bytes[i] == 46 {
        i += 1
        let start = i
        var factor = 0.1
        while i < bytes.count && (48...57).contains(bytes[i]) {
          try meter.work()
          if value == 1 && bytes[i] != 48 { return nil }
          projected += Double(bytes[i] - 48) * factor
          factor /= 10
          i += 1
        }
        guard i > start else { return nil }
      }
      guard projected <= Double(channel == 3 ? 1 : 255) else { return nil }
      values.append(projected)
      while i < bytes.count && bytes[i] == 32 {
        try meter.work()
        i += 1
      }
      let separator: UInt8 = channel == (rgba ? 3 : 2) ? 41 : 44
      guard i < bytes.count && bytes[i] == separator else { return nil }
      i += 1
    }
    guard i == bytes.count else { return nil }
    return .init(
      r: UInt8(values[0]), g: UInt8(values[1]), b: UInt8(values[2]), a: rgba ? values[3] : 1,
      derived: true)
  }
  package static func hinted(
    _ value: JSON, units: JSONHTMLColorUnits, order: JSONHTMLColorOrder, meter: inout JSONWorkMeter
  ) throws -> Self? {
    try meter.retain(512)
    let result = try hintedBody(value, units: units, order: order, meter: &meter)
    try meter.release(512)
    return result
  }
  private static func hintedBody(
    _ value: JSON, units: JSONHTMLColorUnits, order: JSONHTMLColorOrder, meter: inout JSONWorkMeter
  ) throws -> Self? {
    var channels: [JSON] = []
    switch value {
    case .array(let v):
      guard v.count <= 4 else { return nil }
      channels = v
    case .object(let o):
      for key in order == .rgb ? ["r", "g", "b"] : ["r", "g", "b", "a"] {
        try meter.work()
        guard let v = try o.lookup(key, meter: &meter) else { return nil }
        channels.append(v)
      }
      guard o.count == channels.count else { return nil }
    default: return nil
    }
    guard channels.count == (order == .rgb ? 3 : 4) else { return nil }
    var projected: [Double] = []
    for (i, c) in channels.enumerated() {
      try meter.work()
      guard case .number(let n) = c else { return nil }
      if units == .integer8 && i < 3 {
        guard n.components.exponent >= 0 else { return nil }
        // Range/type rejection is local; a real numeric meter failure must propagate.
        guard try n.compare(to: .init(integer: 0), meter: &meter) != .orderedAscending,
          try n.compare(to: .init(integer: 255), meter: &meter) != .orderedDescending
        else { return nil }
        projected.append(Double(try n.integer(as: UInt8.self, meter: &meter)))
      } else {
        guard try n.compare(to: .init(integer: 0), meter: &meter) != .orderedAscending,
          try n.compare(to: .init(integer: 1), meter: &meter) != .orderedDescending
        else { return nil }
        projected.append(try n.doubleValue(policy: .rounded, meter: &meter))
      }
    }
    func byte(_ i: Int) -> UInt8 {
      UInt8(units == .normalized ? (projected[i] * 255).rounded() : projected[i])
    }
    return .init(
      r: byte(0), g: byte(1), b: byte(2), a: projected.count == 4 ? projected[3] : 1, derived: true)
  }
}
