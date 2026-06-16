<!--
 Copyright 2026 Google LLC

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     https://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-->

# A2UI SwiftUI Renderer Agent Guide (AGENTS.md)

This document is the authoritative guide for AI agents operating within the `renderers/swiftui`
directory. It outlines target boundaries, coding conventions, and verification protocols.

---

## 1. Target Architecture & Boundaries

The `A2UISwiftUI` package is purely dedicated to the SwiftUI rendering layer:

* **`A2UISwiftUI`** (`Sources/A2UISwiftUI`):
  * **Purpose**: Native SwiftUI views (`Surface`), environment keys, and data
    binding adapters (`DataBinding+SwiftUI`).
  * **Rule**: **NEVER** add state machine logic, JSON Schema validation, parsing code, or network
    code here. Those belong in `A2UICore` or `JSONSchema` within `renderers/swift_core`.
  * **Rule**: Keep this package focused entirely on declarative view mapping and binding.

---

## 2. Mandatory Coding Conventions for Agents

When creating or modifying Swift source files, agents **MUST** strictly adhere to these rules:

1. **One Type, One File**:
   * Every class, struct, enum, and protocol must reside in its own dedicated Swift file named
     exactly after the type (e.g., `Surface.swift`). Do not group multiple primary types in a
     single file.

2. **100-Character Column Limit**:
   * **No line of code, comment, docstring, or raw JSON block may exceed 100 characters.**
   * Wrap long lines across multiple lines. For long string literals, use Swift string
     concatenation (`+`).

3. **Mandatory Copyright Headers**:
   * Every new file you create must include the standard Google Apache 2.0 copyright header at the
     very top (refer to the template in [DEVELOPMENT.md](DEVELOPMENT.md)).

4. **Swift Testing Suites**:
   * In Swift Testing, class and struct declarations containing `@Test` functions do not require the
     `@Suite` attribute unless they need custom configuration (like displayName or traits). Omit
     redundant `@Suite` attributes to keep test files clean and idiomatic.
   * **Descriptive Raw Identifiers**: Every `@Test` function must be named using the raw backticked
     identifier naming scheme in natural language (e.g. `@Test func `Surface renders loading progress view when root node is nil`()`). Do not use CamelCase or CamelCase-adjacent names for tests.
   * **Public API Testing**: Do not use `@testable import A2UISwiftUI` in any test targets. All tests
     must import the library using standard `import A2UISwiftUI` to ensure that our public API surface
     is fully sufficient, robust, and correctly exposed to external consumers. Testing internals is
     strictly forbidden.

---

## 3. Verification Protocol

Before completing any task, agents **MUST** execute the following verification steps:

1. **Format Code**:
   * Run the Swift formatter from the repository root to ensure all changes conform to style rules:
     ```bash
     swift-format format -i -r Package.swift renderers/swiftui
     ```

2. **Run Unit Tests**:
   * Execute the automated test runner script to compile and run tests on the iOS Simulator:
     ```bash
     ./run_tests.sh
     ```
   * Ensure the `A2UISwiftUITests` target runs and passes completely.
