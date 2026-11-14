# Visual differences

Render the structural difference between two exact values as one static page.

## Overview

``JSONHTMLRenderer/renderDifference(from:to:)`` shows `source` and `target` as one
combined tree. Members and elements that exist only in the target are marked
added, those only in the source are marked removed, and unequal scalars or values
of different kinds are shown as a change from the old value to the new one.
Unequal objects and arrays open into their members and elements. Equal values,
compared with the exact model's equality, stay visible but collapsed: `1.0` and
`1` are equal, and a different member order is not a change.

The page uses the same comparison as `JSONPatch.difference(from:to:options:)` in
JSONPatch. Arrays keep their longest equal prefix and suffix and compare the
remaining elements by position. Elements are never matched as moves.

Each marker carries visually hidden text ("Added: ", "Removed: ", "Changed from
… to "), so the difference does not depend on color. A summary counts the
changes, and a numbered list links every change by its JSON Pointer, in tree
order. A CSS-only "Show changes only" toggle hides unchanged rows.

The page offers three native downloads: the RFC 6902 patch
(`application/json-patch+json`), the source and the target. The patch applies to
the source and yields a value equal to the target. Source and target keep their
exact original number lexemes.

```swift
let page = try JSONHTMLRenderer(options: .init(title: "Release config"))
    .renderDifference(from: before, to: after)
```

## Security and limits

The difference page never contains script, whatever the presentation option.
Its Content Security Policy sets `script-src 'none'` and authorizes the shared
stylesheet and the difference stylesheet by their SHA-256 hashes. All input
text is escaped.

One cumulative budget covers admission of both values, the comparison, the
patch and both downloads, and the final document. The configured
``JSONHTMLLimits`` apply, including document bytes and outline entries (one per
listed change). Cancellation is checked inside the walk.

## Topics

- ``JSONHTMLRenderer/renderDifference(from:to:)``
- ``JSONHTMLRenderer/renderDifferenceWithReport(from:to:)``
