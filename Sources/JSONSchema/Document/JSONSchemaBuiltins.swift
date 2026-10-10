// SPDX-License-Identifier: Apache-2.0
import Foundation
import CryptoKit
import JSON
extension JSONSchemaRegistry {
    /// Loads the integrity-checked packaged Draft 2020-12 meta-schema registry.
    ///
    /// - Returns: Explicit immutable official resources with retained provenance.
    /// - Throws: Missing/corrupt packaged resource, parsing, resource or configuration errors, or cancellation.
    ///
    /// - Parameters:
    ///   - limits: Finite inclusive capacities and work quotas for this call.
    public static func draft2020_12(limits: JSONLimits = .balanced) throws -> Self {
        var meter = try JSONWorkMeter(limits: limits, domain: .schemaCompilation)
        return try Self(admitted: loadBuiltins(meter: &meter))
    }
    package static func loadBuiltins(meter: inout JSONWorkMeter) throws -> [JSONSchemaDocument] {
        let files: [(String, String, UInt64, String)] = [
            ("schema.json", "https://json-schema.org/draft/2020-12/schema", 2452, "41da76f5afb7ce062d248f762463a92f7ca47e4e0f905b224ba6afeef91ded0f"),
            ("meta/applicator.json", "https://json-schema.org/draft/2020-12/meta/applicator", 1659, "c4a6e4147b91fef7fea6dc058cb1bf93402f7414b76578a8b16aaf1dad6aacef"),
            ("meta/content.json", "https://json-schema.org/draft/2020-12/meta/content", 519, "08343747764e4a5814262793cf4d652057a7913863c5950d43297e8e1fdac5b6"),
            ("meta/core.json", "https://json-schema.org/draft/2020-12/meta/core", 1564, "c2d12a8e4dd11d336dfc83a3f663aa4c69f0b49b3beb094ffeb25b5316f4803d"),
            ("meta/format-annotation.json", "https://json-schema.org/draft/2020-12/meta/format-annotation", 448, "abc775adfefd89d22358170d9bf93f4ebd2349563bbbedd60f02bef7c812bcc0"),
            ("meta/format-assertion.json", "https://json-schema.org/draft/2020-12/meta/format-assertion", 445, "c52242b9a1bb786b26c3e82c7add428c31f9c96e575dce99e56ea5feaa6da20c"),
            ("meta/meta-data.json", "https://json-schema.org/draft/2020-12/meta/meta-data", 892, "8f76d6e14f41b9b92ef933b708cdc5144c8b5268651ad11918485fb1754f1c76"),
            ("meta/unevaluated.json", "https://json-schema.org/draft/2020-12/meta/unevaluated", 506, "2dbfbcb73994b670b0976492adee1fffb46c21682784d2f5a4ca561f9e2d0cb4"),
            ("meta/validation.json", "https://json-schema.org/draft/2020-12/meta/validation", 2834, "7010a31e541f32d2be721e2de348df75c9b36876a3ed304877fc0abda1d37a58"),
        ]
        _ = try meter.adding(.schemaDocuments, meter.used(.schemaDocuments), UInt64(files.count))
        var documents: [JSONSchemaDocument] = []
        guard let root = Bundle.module.resourceURL else { throw JSONSchemaCompilationFailure(.metaSchema) }
        for (path, identifier, size, expectedHash) in files {
            try meter.checkpoint(); try meter.charge(.schemaDocuments); try meter.resetValueBounds()
            try meter.require(.inputBytes, size); try meter.charge(.schemaBytes, size); try meter.retain(size)
            let url = root.appendingPathComponent("Resources/Draft2020-12").appendingPathComponent(path)
            let handle: FileHandle
            do { handle = try FileHandle(forReadingFrom: url) }
            catch { throw JSONSchemaCompilationFailure(.metaSchema) }
            defer { try? handle.close() }
            var data = Data()
            while UInt64(data.count) < size {
                let amount = min(Int(size) - data.count, 1024)
                try meter.checkpoint(); try meter.retain(UInt64(amount))
                let chunk: Data
                do { chunk = try handle.read(upToCount: amount) ?? Data() }
                catch { throw JSONSchemaCompilationFailure(.metaSchema) }
                guard !chunk.isEmpty else { throw JSONSchemaCompilationFailure(.metaSchema) }
                for _ in chunk { try meter.work() }
                data.append(chunk)
                try meter.release(UInt64(amount))
            }
            do {
                try meter.checkpoint(); try meter.retain(1)
                guard try handle.read(upToCount: 1)?.isEmpty ?? true else { throw JSONSchemaCompilationFailure(.metaSchema) }
            } catch { throw JSONSchemaCompilationFailure(.metaSchema) }
            try meter.release(1)
            guard UInt64(data.count) == size else { throw JSONSchemaCompilationFailure(.metaSchema) }
            var digest = SHA256(), offset = 0
            while offset < data.count {
                let end = min(offset + Int(meter.limits[.cancellationQuantum]),data.count)
                try meter.retain(UInt64(end-offset))
                let block = Data(data[offset..<end])
                for _ in block { try meter.work() }
                digest.update(data: block); try meter.checkpoint()
                try meter.release(UInt64(end-offset)); offset = end
            }
            var hexadecimal: [UInt8] = []
            func hex(_ nibble: UInt8) -> UInt8 { nibble < 10 ? nibble+48 : nibble+87 }
            for byte in digest.finalize() {
                try meter.work(2); try meter.retain(2)
                hexadecimal.append(hex(byte >> 4)); hexadecimal.append(hex(byte & 15))
            }
            try meter.retain(64); let hash = String(decoding: hexadecimal,as: UTF8.self)
            for _ in hexadecimal { try meter.work() }
            try meter.release(128)
            guard hash == expectedHash else { throw JSONSchemaCompilationFailure(.metaSchema) }
            var bytes: [UInt8] = []
            for byte in data { try meter.work(); try meter.retain(1); bytes.append(byte) }
            let raw = try JSONParser().parse(bytes, meter: &meter)
            switch raw { case .object, .boolean: break; default: throw JSONSchemaCompilationFailure(.metaSchema) }
            let uri = try JSONSchemaURI.parse(identifier, relativeTo: nil, meter: &meter)
            try meter.retain(JSONLogicalWeights.frame)
            documents.append(JSONSchemaDocument(admitted: raw, retrievalURI: uri))
            try meter.release(size * 2)
        }
        return documents
    }
}
