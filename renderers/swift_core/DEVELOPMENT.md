# Development Guide: Build, Test & Coding Standards

This document outlines the development procedures, testing guidelines, and coding standards for the
A2UI Swift Core package. All contributors (humans and AI agents) must strictly adhere to these
conventions.

---

## Prerequisites

Development and local testing require:
* **macOS** with **Xcode** (16.0+) installed.
* **iOS Simulator** installed (iPhone 16 with iOS 18.4 is recommended).
* **swift-format** (installed and available in your shell PATH for formatting check).
* **Podman** (or Docker) installed and running (only required for Bowtie conformance testing).

---

## Running Unit Tests

Since the Swift core package target platform is iOS, tests cannot run natively on macOS command
line via `swift test`. They must be executed on an iOS Simulator using `xcodebuild`.

### 1. The Automated Test Script (Recommended)
We provide a local test runner script that automates simulator discovery and test execution:

```bash
./run_tests.sh
```

This script will:
1. Detect available iOS Simulator destinations on your macOS host.
2. Select the first booted or available simulator (e.g. iPhone 16).
3. Execute the full test suite targeting that simulator via `xcodebuild`.
4. Fall back to a simulator build-only check using `swift build` if no simulator is booted.

### 2. Running Specific Test Targets
If you want to run only one of the test targets to save time:

* **JSONSchemaTests** (Generic JSON Schema tests):
  ```bash
  xcodebuild test -scheme A2UISwiftCore \
    -destination "platform=iOS Simulator,name=iPhone 16,OS=18.4" \
    -only-testing:JSONSchemaTests
  ```

* **A2UIJSONTests** (A2UI-specific schema tests):
  ```bash
  xcodebuild test -scheme A2UISwiftCore \
    -destination "platform=iOS Simulator,name=iPhone 16,OS=18.4" \
    -only-testing:A2UIJSONTests
  ```

---

## Coding Standards & Conventions

To maintain a premium, clean, and highly modular codebase, we enforce four core style rules:

### 1. One Type, One File
* Every class, struct, enum, and protocol must reside in its own dedicated Swift source file named
  after the type (e.g., `JSONValue.swift` contains only the `JSONValue` enum).
* Nested private helper enums or extensions extending that primary type are allowed in the same
  file.

### 2. 100-Character Column Limit
* **Absolutely no line of code, comment, docstring, or JSON literal may exceed 100 characters.**
* Wrap long string literals, comments, and regular expressions across multiple lines using standard
  Swift string concatenation (`+`) or indentations where appropriate.

### 3. Mandatory Copyright & License Header
Every newly created Swift file must start with the exact Google Apache 2.0 license header:

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

### 4. Code Formatting
Before committing any code changes, you must run the repository's native Swift formatter command
from the repository root to ensure perfect styling:

```bash
swift-format format -i -r Package.swift renderers/swift_core
```

---

## Bowtie Conformance Testing

The Bowtie tool tests our generic `JSONSchema` validator against the official JSON Schema Draft
2020-12 conformance suites inside a native Linux container environment.

To run Bowtie:
1. Ensure your local Podman machine is started:
   ```bash
   podman machine start
   ```
2. Run the Bowtie suite runner script:
   ```bash
   cd Tools/A2UIJSONBowtie
   ./run_bowtie.sh
   ```

This script will:
* Build a native Linux container image containing our Swift compilation environment.
* Spin up the Bowtie CLI harness.
* Validate all draft 2020-12 test cases and print a beautiful markdown summary table showing
  our conformance results.
