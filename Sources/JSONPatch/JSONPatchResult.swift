// SPDX-License-Identifier: Apache-2.0
import JSON
public enum JSONPatchResult: Sendable, Equatable { case document(JSON), removed }
