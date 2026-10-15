# CLI foundation

This feature boundary implements format, strict validation, RFC 6901 selection,
staged RFC 6902 application and HTML/text/Markdown rendering. It does not advertise
the query engine, stream/schema command adapters or provider helpers before their
own increments are qualified. The target release is 1.4.0; this is development source.

## Composition and ownership

`CLIJobContext: ~Copyable` lives in the private runtime target. Argv, native parsing,
number projection, registry/plan admission, validation, Patch, rendering and writing
borrow its one `JSONWorkMeter`. Package-only borrowed entry points introduce no new
public library signatures. Switching the operation domain changes subsystem work
accounting without replacing health or counters. Only per-value shape capacities
reset; consumed work never resets. Patch refunds its local staging reservation and
preserves ownership that preceded its invocation.

CLI policy has 16 additional finite quotas. Core policy keeps exactly 49 metric
identifiers. Effective work and logical-retention ceilings are the intersection of
CLI and core ceilings. Configuration bootstraps under the finite offline profile,
then validates requested caps against already consumed work and admitted capacities.
Explicit finite overrides reuse the ledger. They cannot erase bootstrap input.

Error/cancellation latches terminal health. Data paths cannot resume after failure.
Diagnostics reserve finite work and buffer ownership before command execution;
the bounded terminal serializer spends that reservation and cannot reopen the job.
Reports distinguish provisional results from fully accepted stdout results and
atomically installed file results. Logical retained bytes are not process RSS.

## Native I/O

The adapters poll nonblocking POSIX descriptors, check cancellation between polls,
and handle short reads/writes, EINTR, EAGAIN, EOF and broken pipes explicitly.
Filesystem/kernel work is foreign work; cancellation does not claim to interrupt
a filesystem operation already executing in the kernel. Borrowed stdio flags are
restored. The signal callback is explicitly `@Sendable`; a real subprocess test
caught and fixed an inferred-actor dispatch assertion on SIGINT.

File output uses an exclusive owned temporary in the destination directory.
Installation happens after parsing, command evaluation, writing and close succeed.
No-overwrite installation uses link/unlink; explicit overwrite uses rename.
Existing destinations, final symlinks and input aliases/hard links are checked.
Failures remove only the invocation's temporary and preserve the destination.
Concurrent pathname replacement by another process is outside this adapter's
transactional guarantee. There is no cross-filesystem fallback, mkdir, fsync or
power-loss durability claim. Previously accepted stdout bytes cannot be recalled.

## Checks

Twelve meaningful Swift Testing functions include four parameter cases. The executable
subprocess harness has 53 cases covering exact lexemes/scalar keys, strict errors,
schema invalidity versus operational failure, bounded issues, Pointer null/absence,
root removal, failed Patch staging, renderer selection, limits/reports, filesystem
aliases, atomic cleanup and SIGINT while stdin is idle. The initial failure receipts
are retained; the corrected subprocess lane passes all 53.

The event receipt reader is reused from the separately qualified 1.3 export work
at `1e0b86d2580bb9678039597523aa3b99d2905abf`. No export/PDF feature source is copied.
The six-product checks retain exact target/dependency/toolchain/platform assertions,
all baseline test bundle counts, 173 inherited parameter cases plus four CLI cases,
and all 49 cap probe outcomes. Native/safety/docs qualification remains required
for the committed source.

## Compiler probes and review corrections

The supported native compiler accepts an inout job borrow, rejects consuming the
same job twice with the expected ownership diagnostic, and rejects access from an
external package. The noncopyable initializer constructs its meter before the
other stored assignments; this follows actual Swift 6.4 initialization rules.
An initial default-CLT/cache attempt is unqualified and retained as blocked evidence;
its negative exits are not ownership passes.

Strict memory-safety compilation marks individual synchronous POSIX pointer and
CString expressions `unsafe`. Byte pointers stay within `withUnsafeBytes` scopes;
counts are checked against the array slice, poll/stat pointers address live local
structures, and C strings are borrowed only for a synchronous syscall. No pointer
escapes, suspension crosses a borrow, unsafe compiler option or blanket annotation
is introduced.

The SIGINT acceptance test waits for its exclusive staging file as a readiness
signal and holds stdin open until exit. Closing stdin through `communicate()`
immediately after SIGINT introduced a competing EOF and was corrected. The test
still requires exit 130, no output, and complete staging cleanup.

The final argument adapter reads process-owned C argv under the finite bootstrap
ledger, rejects invalid UTF-8 instead of accepting replacement characters, and
checks each byte before copying. Structured diagnostic preferences survive usage
errors. Malformed/overflowing limit configuration is usage failure; exhaustion,
cancellation and I/O remain operational. Missing array Pointer targets use a
package-only presence adapter over the shared strict index decoder; malformed
indices and wrong kinds stay errors. Existing public Pointer resolution retains
its previous error contract. These review findings have dedicated regressions.

Named inputs open with O_NONBLOCK from the initial syscall, so FIFO open does not
wait indefinitely before cancellation handling begins. Subprocess cancellation
covers both idle borrowed stdin and an owned named FIFO. Reports include actual
enforced native caps, remaining cumulative work and profile/override origin.

The terminal diagnostic builder checks each append before growth and discards an
incomplete report before handoff. Zero forbids diagnostic output; small diagnostic
quotas cannot produce broken JSONL. HTML-specific quotas map to resource exit 6;
renderer configuration maps to usage exit 2. Typed schema compile/evaluation errors
stay operational exit 5, with stable subsystem codes. These have explicit regressions.
