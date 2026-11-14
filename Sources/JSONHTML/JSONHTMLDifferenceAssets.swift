// SPDX-License-Identifier: Apache-2.0
// Fixed difference CSS from Assets/Difference.css; CSP hashes exactly these UTF-8 bytes.
package enum JSONHTMLDifferenceAssets {
    package static let css = #"""
/* SPDX-License-Identifier: Apache-2.0; Swift-JSON difference asset v1 */
.diff{--add:#1a7f37;--add-bg:#dafbe1;--del:#b42318;--del-bg:#ffebe9;--chg:#9a6700;--chg-bg:#fff4d6}
.diff.dark{--add:#5fd88a;--add-bg:#12361f;--del:#ff8f87;--del-bg:#45191a;--chg:#f2c45b;--chg-bg:#3a2d0d}
@media(prefers-color-scheme:dark){.diff.automatic{--add:#5fd88a;--add-bg:#12361f;--del:#ff8f87;--del-bg:#45191a;--chg:#f2c45b;--chg-bg:#3a2d0d}}
.diff .diff-summary{display:flex;gap:.75rem;flex-wrap:wrap}.diff .diff-count{font-weight:600;padding:.1rem .5rem;border-radius:.4rem}
.diff .diff-count.diff-added{color:var(--add);background:var(--add-bg)}.diff .diff-count.diff-removed{color:var(--del);background:var(--del-bg)}.diff .diff-count.diff-changed{color:var(--chg);background:var(--chg-bg)}
.diff .diff-downloads a{margin-right:1rem}.diff .diff-list{list-style:none;padding:0;margin:.4rem 0 0;display:grid;gap:.35rem}
.diff .diff-row{border-left:4px solid transparent;padding-left:.6rem}.diff .diff-row.diff-added{border-left-color:var(--add)}.diff .diff-row.diff-removed{border-left-color:var(--del)}.diff .diff-row.diff-changed{border-left-color:var(--chg)}
.diff ins{text-decoration:none;background:var(--add-bg);border-radius:.25rem}.diff del{text-decoration:line-through;background:var(--del-bg);border-radius:.25rem}
.diff .diff-value{margin:0;display:inline;white-space:pre-wrap;overflow-wrap:anywhere;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}.diff pre.diff-value{display:block;padding:.3rem .45rem}
.diff .diff-mark{display:inline-block;width:1.2em;font-weight:700}.diff .diff-added>.diff-mark,.diff .diff-added>dd>.diff-mark{color:var(--add)}.diff .diff-removed>.diff-mark,.diff .diff-removed>dd>.diff-mark{color:var(--del)}.diff .diff-changed>.diff-mark,.diff .diff-changed>dd>.diff-mark{color:var(--chg)}
.diff .diff-arrow{padding:0 .3rem}.diff .diff-unchanged>summary{color:var(--muted);cursor:pointer}.diff .diff-changes li a{text-decoration:none}.diff .diff-changes li.diff-added a{color:var(--add)}.diff .diff-changes li.diff-removed a{color:var(--del)}.diff .diff-changes li.diff-changed a{color:var(--chg)}
.diff:has(#jd-only:checked) .diff-same{display:none}.diff .diff-row:target{outline:2px solid currentColor;outline-offset:2px}
@media(forced-colors:active){.diff ins,.diff del,.diff .diff-count{background:Canvas;color:CanvasText;border:1px solid CanvasText}.diff .diff-row{border-left-color:CanvasText}}
@media print{.diff .diff-filter,.diff .diff-downloads{display:none}.diff ins,.diff del{background:none}.diff ins{text-decoration:underline}}
"""#
    package static let cssHash = "Yxkb5kFSD0GtznECmpxmXaIKNx+nS67jT/X9lvKJV2I="
}
