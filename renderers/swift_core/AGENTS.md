# A2UI Swift Core Agent Guide (AGENTS.md)

This document is the authoritative guide for AI agents operating within the `renderers/swift_core`
directory. It outlines target boundaries, coding conventions, and verification protocols.

---

## 1. Target Architecture & Boundaries

The package is divided into two distinct targets. Agents must strictly respect their boundaries:

1. **`JSONSchema`** (`Sources/JSONSchema`):
   * **Purpose**: Generic JSON Schema Draft 2020-12 validator and DSL builder.
   * **Rule**: **NEVER** add A2UI-specific types, schemas, event validations, or
     tests here. Keep this target completely independent, generic, and
     specification-compliant.

2. **`A2UIJSON`** (`Sources/A2UIJSON`):
   * **Purpose**: Contains A2UI-specific common type schemas (like
     `ActionSchema`, `ChildListSchema`, etc.).
   * **Rule**: Place all A2UI-specific logic and schemas here. This target depends on `JSONSchema`.

3. **`A2UICore`** (`Sources/A2UICore`):
   * **Purpose**: Stateful core engine (SurfaceViewModel, MessageProcessor, Node,
     DataBinding, ResolvedAction).
   * **Rule**: Place all stateful runtime logic and engine implementations here. This target
     depends on `A2UIJSON` and `JSONSchema`.

---

## 2. Mandatory Coding Conventions for Agents

When creating or modifying Swift source files, agents **MUST** strictly adhere to these rules:

1. **One Type, One File**:
   * Every class, struct, enum, and protocol must reside in its own dedicated Swift file named
     exactly after the type (e.g. `Box.swift`). Do not group multiple primary types in a single
     file.

2. **100-Character Column Limit**:
   * **No line of code, comment, docstring, or raw JSON block may exceed 100 characters.**
   * You must wrap long lines across multiple lines. For long string literals or regular
     expressions, use Swift string concatenation (`+`).

3. **Mandatory Copyright Headers**:
   * Every new file you create must include the standard Google Apache 2.0 copyright header at the
     very top (refer to the template in
     [DEVELOPMENT.md](DEVELOPMENT.md#3-mandatory-copyright--license-header)).

4. **Swift Testing Suites**:
   * In Swift Testing, class and struct declarations containing `@Test` functions do not
     require the `@Suite` attribute unless they need custom configuration (like
     displayName or traits). Omit redundant `@Suite` attributes to keep test files clean
     and idiomatic.

---

## 3. Verification Protocol

Before completing any task, agents **MUST** execute the following verification steps:

1. **Format Code**:
   * Run the Swift formatter from the repository root to ensure all changes conform to style rules:
     ```bash
     swift-format format -i -r Package.swift renderers/swift_core
     ```

2. **Run Unit Tests**:
   * Execute the automated test runner script to compile and run tests on the iOS Simulator:
     ```bash
     ./run_tests.sh
     ```
   * Ensure all three test targets (`JSONSchemaTests`, `A2UIJSONTests`, and `A2UICoreTests`) run.
     The script is configured to explicitly run them under `xcodebuild`.


3. **Compile Bowtie Harness**:
   * Ensure that the Bowtie CLI harness builds successfully on macOS:
     ```bash
     cd Tools/A2UIJSONBowtie && swift build
     ```
