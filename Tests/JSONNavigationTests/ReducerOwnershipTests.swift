// SPDX-License-Identifier: Apache-2.0
import Foundation
import Synchronization
import Testing
import JSON
import JSONNavigation

private enum ReducerMarker: Error { case replacement }
private struct ProbeReducer: JSONTraversalOwnedReducer {
    enum Mode { case noop, charged, retained, caughtType, cancellation, path }
    var mode = Mode.noop
    var replaceFinalError = false
    var hits: [JSONTraversalHit] = [] // Independent qualification oracle; caller storage.
    var path: [JSONLocationComponent] = []
    var span: JSONSourceSpan?
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        hits.append(hit)
        switch mode {
        case .noop: break
        case .charged: try context.work(7)
        case .retained: try context.retain(96)
        case .caughtType:
            do { _ = try context.arrayCount(value, at: hit.absoluteLocation) } catch { }
        case .cancellation:
            withUnsafeCurrentTask { $0?.cancel() }
            do { try context.checkpoint() } catch { }
            throw ReducerMarker.replacement
        case .path:
            if hit.relativeDepth == 1 {
                path = try context.appending(.key(""), to: hit.absoluteLocation)
            }
        }
        return .continue
    }
    mutating func finish(_ summary: JSONTraversalSummary,
                         context: inout JSONTraversalContext) throws -> JSONTraversalSummary {
        if mode == .charged {
            do { try context.work(11) }
            catch { if replaceFinalError { throw ReducerMarker.replacement }; throw error }
        }
        if mode == .path { span = try context.sourceSpan(at: path) }
        return summary
    }
}

@Test func navigationReducerNoopPreservesEveryPublicStatistic() throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"rows":[{"id":1},null],"":[]}"#)))
    let scopes: [JSONTraversalScope] = [.subtree(at: []), .subtree(at: [.key("rows")]),
        .virtual(roots: [[.key("rows")], [.key("")]], overlap: .rejectAmbiguous),
        .virtual(roots: [[], [.key("rows")]], overlap: .uniquePhysicalNodes)]
    for scope in scopes {
        var hits: [JSONTraversalHit] = [], reducer = ProbeReducer()
        let ordinary = try walk.visit(scope: scope) { hit, _ in hits.append(hit); return .continue }
        let owned = try walk.inspectOwned(scope: scope, reducer: &reducer)
        #expect(hits == reducer.hits)
        #expect(ordinary.result.visitedCount == owned.result.visitedCount)
        #expect(ordinary.result.completion == owned.result.completion)
        for metric in JSONResourceMetric.allCases {
            #expect(ordinary.statistics[metric] == owned.statistics[metric])
        }
        #expect(ordinary.statistics.peakLogicalRetainedBytes == owned.statistics.peakLogicalRetainedBytes)
    }
}

@Test func navigationReducerChargesObservationAndFinalizationOnce() throws {
    let walk = JSONTraversal(document: .init(root: [0, 1, 2]))
    let ordinary = try walk.visit { _, _ in .continue }
    var reducer = ProbeReducer(mode: .charged)
    let owned = try walk.inspectOwned(reducer: &reducer)
    #expect(owned.result.visitedCount == 4)
    #expect(owned.statistics[.nodes] == 4)
    #expect(owned.statistics[.workUnits] == ordinary.statistics[.workUnits] + 39)
}

@Test func navigationReducerInclusiveQuotaAndOriginalTerminalPriority() throws {
    let document = JSONDocument(root: [0, 1, 2])
    func run(_ limits: JSONLimits, replace: Bool = false) throws -> JSONOperationReport<JSONTraversalSummary> {
        var reducer = ProbeReducer(mode: .charged, replaceFinalError: replace)
        return try JSONTraversal(document: document, limits: limits).inspectOwned(reducer: &reducer)
    }
    let baseline = try run(.balanced)
    var limits = JSONLimits.balanced; limits[.workUnits] = baseline.statistics[.workUnits]
    #expect(try run(limits).statistics[.workUnits] == baseline.statistics[.workUnits])
    limits[.workUnits] -= 1
    for replace in [false, true] {
        do { _ = try run(limits, replace: replace); Issue.record("Expected quota refusal") }
        catch let error as JSONFailure {
            #expect(error.resource?.metric == .workUnits && error.resource?.domain == .core)
            #expect(error.resource?.attemptedUsage == baseline.statistics[.workUnits])
        }
    }
}

@Test func navigationReducerRetainedOutputsUseOriginalPeak() throws {
    func run(_ limits: JSONLimits) throws -> JSONOperationReport<JSONTraversalSummary> {
        var reducer = ProbeReducer(mode: .retained)
        return try JSONTraversal(document: .init(root: .null), limits: limits).inspectOwned(reducer: &reducer)
    }
    let baseline = try run(.balanced)
    #expect(baseline.statistics[.retainedBytes] == 96)
    var limits = JSONLimits.balanced; limits[.retainedBytes] = baseline.statistics.peakLogicalRetainedBytes
    #expect(try run(limits).result.visitedCount == 1)
    limits[.retainedBytes] -= 1
    do { _ = try run(limits); Issue.record("Expected retention refusal") }
    catch let error as JSONFailure { #expect(error.resource?.metric == .retainedBytes) }
}

@Test func navigationReducerCaughtOwnedTypeErrorRemainsTerminal() throws {
    var reducer = ProbeReducer(mode: .caughtType)
    do {
        _ = try JSONTraversal(document: .init(root: .null)).inspectOwned(reducer: &reducer)
        Issue.record("Caught owned failure cannot return success")
    } catch let error as JSONAccessFailure {
        #expect(error.cause.code == .wrongKind && error.path.isEmpty)
    }
}

@Test func navigationReducerCancellationCannotBecomeReplacementError() async throws {
    let task = Task {
        var reducer = ProbeReducer(mode: .cancellation)
        return try JSONTraversal(document: .init(root: [0, 1, 2])).inspectOwned(reducer: &reducer)
    }
    do { _ = try await task.value; Issue.record("Expected cancellation") }
    catch is CancellationError { }
}

@Test func navigationReducerPathsAndSpansKeepCoreAuthority() throws {
    let document = try JSONParser().parseDocument(Data(#"{"rows":[{"":1}]}"#.utf8))
    var reducer = ProbeReducer(mode: .path)
    _ = try JSONTraversal(document: document).inspectOwned(scope: .subtree(at: [.key("rows")]), reducer: &reducer)
    #expect(reducer.path == [.key("rows"), .index(0), .key("")])
    #expect(try JSONPointer(tokens: ["rows", "0", ""]).resolve(in: document.root) == 1)
    #expect(reducer.span == (try document.sourceMap?.span(at: reducer.path)))
}

@Test func navigationReducerScopeReleasesRootSourceAndStateOnEveryExit() throws {
    let observations = Mutex<[(Bool, Bool)]>([])
    let document = try JSONParser().parseDocument(Data("[0,1,2]".utf8))
    var walk = JSONTraversal(document: document)
    walk.lifetimeObserver = { rootReleased, stateReleased in
        observations.withLock { $0.append((rootReleased, stateReleased)) }
    }
    var reducer = ProbeReducer()
    #expect(try walk.inspectOwned(reducer: &reducer).statistics[.retainedBytes] == 0)
    reducer = ProbeReducer(mode: .caughtType)
    do { _ = try walk.inspectOwned(reducer: &reducer); Issue.record("Expected type refusal") }
    catch is JSONAccessFailure { }
    let facts = observations.withLock { $0 }
    #expect(facts.count == 2 && facts.allSatisfy { $0.0 && $0.1 })
    // The immutable traversal and caller still own their source; this checks only
    // the invalidated invocation's optional root/source/state, not process RSS.
}
