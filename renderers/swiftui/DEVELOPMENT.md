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

# Development Guide: Build, Test & Style Rules

This document outlines the development procedures, testing guidelines, and coding standards for the
A2UI SwiftUI renderer package.

---

## Prerequisites

Development and testing require:
* **macOS** with **Xcode** (16.0+) installed.
* **iOS Simulator** installed (iPhone 16 with iOS 18.4 is recommended).
* **swift-format** (installed and available in your shell PATH for formatting).

---

## Running Unit Tests

Because the package targets iOS, unit tests must be executed on an iOS Simulator using
`xcodebuild` or compiled for the simulator destination as a fallback.

### 1. The Automated Test Script

We provide a local test runner script in the `swiftui` directory:

```bash
./run_tests.sh
```

This script will:
1. Detect available iOS Simulator destinations on your macOS host.
2. Select the first booted or available simulator (e.g. iPhone 16).
3. Execute the SwiftUI test suite (`A2UISwiftUITests`) targeting that simulator via `xcodebuild`.
4. Fall back to a simulator build-only check using `swift build` if no simulator is found.

### 2. Running via Command Line Manually

To run the tests on a specific simulator manually:

```bash
xcodebuild test -scheme A2UISwiftCore-Package \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=18.4" \
  -only-testing:A2UISwiftUITests
```

---

## Coding Standards & Style Rules

To maintain consistency with the rest of the A2UI Swift packages, we enforce the following rules:

### 1. One Type, One File

* Every class, struct, enum, and protocol must reside in its own dedicated Swift source file named
  exactly after the type (e.g., `Surface.swift`).
* Private helper types and extensions of that primary type are allowed in the same file.

### 2. 100-Character Column Limit

* **Absolutely no line of code, comment, docstring, or raw JSON block may exceed 100 characters.**
* Wrap long string literals, comments, and declarations across multiple lines.

### 3. Mandatory Copyright Header

Every newly created Swift file must start with the standard Google Apache 2.0 license header:

```swift
// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
```

### 5. Descriptive Raw Test Identifiers

* **Every `@Test` function in our test suites must use Swift's raw backticked identifier naming scheme in natural language.**
* Do not use CamelCase or snake_case for test function names.
* E.g., write `@Test func `Surface renders loading progress view when root node is nil`()` instead of `@Test func testSurfaceRendersNilRoot()`.
* This ensures that test reports generated in Xcode, the command line, and CI are extremely readable and serve as living, human-friendly documentation.

### 6. Public API Testing Only

* **Do not use `@testable import A2UISwiftUI` in any test targets.**
* All tests must import the library using standard `import A2UISwiftUI` to ensure that our public API surface is fully sufficient, robust, and correctly exposed to external consumers.
* Testing internals is forbidden; we test behaviors through public interfaces. This guarantees that refactoring internals will not break tests.

### 7. Code Formatting

Before submitting any code changes, run the Swift formatter from the repository root:

```bash
swift-format format -i -r Package.swift renderers/swiftui
```
