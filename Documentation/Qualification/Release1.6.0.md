# Swift-JSON 1.6.0 qualification and compatibility

Version 1.6.0 combines the optional JSONSchemaExamples and JSONNavigation products,
bounded native composition, structured HTML previews and the 1.5.1 maintenance
repairs. Eight libraries and swift-json retain an empty root dependency graph.
JSONRegexRuntime, JSONFilterRuntime and JSONCLIEngine remain package-private.
Swift tools/compiler 6.4+, language mode 6 and the Apple 27 deployment baseline
remain unchanged. Original Apache-2.0 code and upstream notices are retained.

## Source and qualification

The integrated implementation was reviewed in [G8](../Architecture/Release1.6/G8Qualification.md).
The subsequent guide-index repair passed exact-source
[Native qualification](https://github.com/ThorFuchs/Swift-JSON/actions/runs/38896585384)
and [ARM64/x86_64 Linux qualification](https://github.com/ThorFuchs/Swift-JSON/actions/runs/38896585432)
at `a53e8ce67a9086088e6aa9ce7d94d83fd2fc932c`, followed by successful automatic
Pages deployment. These remain source-bound historical receipts.

Release metadata changes the CLI's displayed version from `1.6.0-dev` to `1.6.0`,
regenerates its source digest and reconciles current documentation. It does not
change parsing, values, schema evaluation, construction, traversal, rendering,
resource profiles, discovery counts or dependencies. The exact tag's final
qualification receipt, reproducible source archive, matching compiled DocC catalogs
and checksums accompany its GitHub release. A prepared draft is not publication.

The qualification inventory requires 695 Native / 679 Linux root functions, 325
parameter invocations, 47 Native / 46 Linux shared-state functions and all 49 core
cap outcomes. Policy exclusions remain separate from evaluated successes. Full
Native qualification is repeated from a Git-free source extraction and its archive
must reconstruct byte for byte. Consumers use public products and offline resources.

## Compatibility and limits

- JSONSchemaExamples is an opt-in conservative constructor. Every returned value
  receives a completed native verdict against the original root. Search refusal,
  unsupported construction and operational errors remain distinct; incomplete
  search does not prove unsatisfiability. Native format/default/reference semantics
  stay authoritative.
- JSONNavigation is opt-in; one-node lookup remains in JSON. It provides exact
  traversal and explicit coverage, not the deferred N2 inspection API.
- JSONHTML now defaults to interactive structured inspection. Choose the explicit
  syntax layout for syntax-first presentation. Prefix previews retain access to
  complete originals. Browser, receiver and opaque SDK work are separate from owned
  generation quotas.
- Composition qualification reports five completed imports and three operational
  quota refusals. The direct balanced 128/128 capacity target remains blocked;
  no arbitrary production capacity follows from passing characterization tests.
- Finite cumulative work and logical retained bytes are policies, not process RSS,
  caller instruction quotas or universal throughput guarantees. Existing
  [performance dispositions](../Performance/README.md), including the reviewed
  streaming regression and unchanged 10% review trigger, remain in force.
- Historical mobile/WASI evidence retains its exact source and host scope. G8
  recorded current SDK/simulator checks but no new physical-iPhone execution;
  physical iPad remains deferred under the existing simulator policy. Full CLI/WASI
  hosting, Apple model helpers, E11 projection and E12 framing remain outside scope.

## Documentation

Eight native DocC catalogs preserve all guide and symbol URLs. Each authored-guide
namespace receives its catalog's unchanged native navigator index. Missing, stale
or foreign indexes and missing indexed routes fail the documentation gate.

Two web-client observations remain explicit:

- Reusing a tab across catalogs could reach DocC's generic error page. Earlier QA
  reproduced this on the unchanged baseline; fresh direct guide loads passed.
- One production HTML-guide load logged a lazy JavaScript chunk error while its
  article and navigator rendered. That exact asset returned HTTP 200 and matched
  the qualified artifact; a fresh load and original-tab reload passed with no new
  errors. Its root cause remains unresolved.

Direct guide URLs or a reload are practical recovery paths. The navigator repair
does not claim universally error-free DocC runtime behavior. Matching compiled
catalogs can also be opened in Xcode, independently of the public website's current
main deployment. See [documentation tooling](../DocumentationTooling.md).
