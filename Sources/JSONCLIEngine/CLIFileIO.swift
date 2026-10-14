// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONFilterRuntime
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif

/// POSIX adapters poll and use nonblocking descriptors so cancellation can be observed
/// between bounded reads/writes. The kernel and filesystem's own work are outside quotas.
package final class CLIInput {
    private let fd: Int32
    private let owned: Bool
    private let priorFlags: Int32
    package let path: String
    package init(path: String) throws {
        self.path = path; owned = path != "-"
        fd = unsafe (owned ? open(path, O_RDONLY | O_NONBLOCK) : STDIN_FILENO)
        guard fd >= 0 else { throw CLIError(.io, "openInput") }
        priorFlags = fcntl(fd, F_GETFL)
        guard priorFlags >= 0, fcntl(fd, F_SETFL, priorFlags | O_NONBLOCK) == 0 else {
            if owned { _ = close(fd) }; throw CLIError(.io, "nonblockingInput")
        }
    }
    deinit { if owned { _ = close(fd) } else { _ = fcntl(fd, F_SETFL, priorFlags) } }
    package func next(context: inout CLIJobContext) throws -> [UInt8]? {
        try context.checkpoint()
        let capacity = min(UInt64(16384), context.limits.core[.chunkBytes])
        try context.require(.retainedBytes, context.used(.retainedBytes) + capacity)
        try context.meter.retain(capacity)
        defer { try? context.meter.release(capacity) }
        var bytes = [UInt8](repeating: 0, count: Int(capacity))
        guard capacity > 0 else { throw CLIError(.resource, "limitExceeded", metric: "chunkBytes") }
        while true {
            try context.work()
            var state = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let ready = unsafe poll(&state, 1, 100)
            if ready < 0 { if errno == EINTR { continue }; throw CLIError(.io, "pollInput") }
            if ready == 0 { continue }
            let count = bytes.withUnsafeMutableBytes { unsafe read(fd, $0.baseAddress, $0.count) }
            if count < 0 { if errno == EINTR || errno == EAGAIN { continue }; throw CLIError(.io, "readInput") }
            guard count > 0 else { return nil }
            try context.charge(.totalInputBytes, UInt64(count)); try context.work(UInt64(count))
            try context.meter.retain(UInt64(count)); try context.work(UInt64(count))
            return Array(bytes.prefix(count))
        }
    }
    package func document(context: inout CLIJobContext) throws -> JSON {
        let retainedAtEntry = context.meter.used(.retainedBytes)
        var bytes: [UInt8] = []
        while let chunk = try next(context: &context) {
            try context.meter.require(.inputBytes, UInt64(bytes.count) + UInt64(chunk.count))
            try context.work(UInt64(chunk.count)); try context.meter.retain(UInt64(chunk.count))
            bytes.append(contentsOf: chunk); try context.meter.release(UInt64(chunk.count))
        }
        try context.domain(.parsing)
        let value = try JSONParser().parse(bytes, meter: &context.meter)
        // Source bytes are dropped; parser-owned exact value state remains charged.
        try context.meter.release(UInt64(bytes.count))
        guard context.meter.used(.retainedBytes) >= retainedAtEntry else { throw CLIError(.usage, "invalidOwnership") }
        try context.charge(.totalRecords)
        return value
    }
}
package final class CLIOutput {
    private let fd: Int32
    private let priorFlags: Int32
    private let destination: String?
    private var staging: String?
    private let overwrite: Bool
    private var closed = false
    package init(destination: String?, overwrite: Bool, inputs: [String], context: inout CLIJobContext) throws {
        self.destination = destination; self.overwrite = overwrite
        if let destination {
            try context.work(UInt64(destination.utf8.count)); try context.meter.retain(UInt64(destination.utf8.count) * 2 + 128)
            try Self.checkDestination(destination, overwrite: overwrite, inputs: inputs)
            let parent = URL(fileURLWithPath: destination).deletingLastPathComponent().path
            let temporary = parent + "/.swift-json-" + UUID().uuidString + ".tmp"
            let opened = unsafe open(temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode_t(0o600))
            guard opened >= 0 else { throw CLIError(.io, "openStaging") }
            fd = opened; staging = temporary
        } else { fd = STDOUT_FILENO }
        priorFlags = fcntl(fd, F_GETFL)
        guard priorFlags >= 0, fcntl(fd, F_SETFL, priorFlags | O_NONBLOCK) == 0 else {
            if destination != nil { _ = close(fd); if let staging { _ = unsafe unlink(staging) } }
            throw CLIError(.io, "nonblockingOutput")
        }
    }
    deinit {
        if !closed {
            if destination != nil { _ = close(fd) }
            else { _ = fcntl(fd, F_SETFL, priorFlags) }
        }
        if let staging { _ = unsafe unlink(staging) }
    }
    private static func checkDestination(_ path: String, overwrite: Bool, inputs: [String]) throws {
        var info = stat()
        if unsafe lstat(path, &info) == 0 {
            guard info.st_mode & mode_t(S_IFMT) != mode_t(S_IFLNK) else { throw CLIError(.io, "outputSymlink") }
            guard overwrite else { throw CLIError(.io, "outputExists") }
            for input in inputs where input != "-" {
                var source = stat()
                if unsafe stat(input, &source) == 0, info.st_dev == source.st_dev, info.st_ino == source.st_ino { throw CLIError(.io, "inputOutputCollision") }
            }
        } else if errno != ENOENT { throw CLIError(.io, "inspectOutput") }
        let target = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        for input in inputs where input != "-" {
            if URL(fileURLWithPath: input).standardizedFileURL.resolvingSymlinksInPath().path == target { throw CLIError(.io, "inputOutputCollision") }
        }
    }
    package func write(_ bytes: [UInt8], context: inout CLIJobContext) throws {
        try context.charge(.totalOutputBytes, UInt64(bytes.count))
        if destination != nil { try context.charge(.diskStagingBytes, UInt64(bytes.count)) }
        try context.work(UInt64(bytes.count))
        try CLISinkTransfer.writeAll(count: bytes.count, context: &context) { range, context in
            var state = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            let ready = unsafe poll(&state, 1, 100)
            if ready < 0 { if errno == EINTR { return nil }; throw CLIError(.io, "pollOutput") }
            if ready == 0 { return nil }
            try context.checkpoint()
            let count = bytes.withUnsafeBytes { unsafe writeDescriptor(fd, $0.baseAddress!.advanced(by: range.lowerBound), range.count) }
            if count < 0 { if errno == EINTR || errno == EAGAIN { return nil }; throw CLIError(.io, "writeOutput") }
            return count
        }
    }
    package func resultAccepted(context: inout CLIJobContext) {
        if destination == nil { context.committedResults = context.used(.totalResults) }
    }
    package func finish(inputs: [String], context: inout CLIJobContext) throws {
        try context.checkpoint()
        if let destination, let staging {
            // close(2) errors are operational, and no install happens before close succeeds.
            let status = close(fd); closed = true
            guard status == 0 else { throw CLIError(.io, "closeOutput") }
            try Self.checkDestination(destination, overwrite: overwrite, inputs: inputs)
            let installed = unsafe (overwrite ? rename(staging, destination) : link(staging, destination))
            guard installed == 0 else { throw CLIError(.io, "installOutput") }
            if !overwrite { _ = unsafe unlink(staging) }
            self.staging = nil
        }
        context.committedResults = context.used(.totalResults)
    }
}
private func writeDescriptor(_ fd: Int32, _ bytes: UnsafeRawPointer, _ count: Int) -> Int {
    #if canImport(Darwin)
    unsafe Darwin.write(fd, bytes, count)
    #elseif canImport(Glibc)
    unsafe Glibc.write(fd, bytes, count)
    #elseif canImport(WASILibc)
    unsafe WASILibc.write(fd, bytes, count)
    #endif
}
