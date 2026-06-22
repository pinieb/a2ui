# A2UI Swift Core Agent Guide (AGENTS.md)

This document is the authoritative guide for AI agents operating within the `renderers/swift_core`
directory. It outlines target boundaries, coding conventions, and verification protocols.

---

## 1. Target Architecture & Boundaries

The package is divided into distinct targets. Agents must strictly respect their boundaries:

1. **`JSONSchema`** (`JSONSchema/Sources`):
   - **Purpose**: Generic JSON Schema Draft 2020-12 validator and DSL builder.
   - **Rule**: **NEVER** add A2UI-specific types, schemas, event validations, or
     tests here. Keep this target completely independent, generic, and
     specification-compliant.

---

## 2. Mandatory Coding Conventions for Agents

When creating or modifying Swift source files, agents **MUST** strictly adhere to these rules:

1. **One Type, One File**:
   - Every class, struct, enum, and protocol must reside in its own dedicated Swift file named
     exactly after the type (e.g. `Box.swift`). Do not group multiple primary types in a single
     file.

2. **100-Character Column Limit**:
   - **No line of code, comment, docstring, or raw JSON block may exceed 100 characters.**
   - You must wrap long lines across multiple lines. For long string literals, use Swift
     multiline string literals (`"""`) or indentations where appropriate.

3. **Mandatory Copyright Headers**:
   - Every new file you create must include the standard Google Apache 2.0 copyright header at the
     very top. Refer to the header template in
     [CODING_STANDARDS.md](CODING_STANDARDS.md#3-headers-copyright-and-license).

4. **Swift Testing Suites**:
   - In Swift Testing, class and struct declarations containing `@Test` functions do not
     require the `@Suite` attribute unless they need custom configuration (like
     displayName or traits). Omit redundant `@Suite` attributes to keep test files clean
     and idiomatic.

---

## 3. Verification Protocol

Before completing any task, agents **MUST** execute the following verification steps:

1. **Format Code**:
   - Run the formatting script from the repository root to ensure all changes conform
     to style rules:
     ```bash
     ./scripts/fix_format.sh
     ```

2. **Run Unit Tests**:
   - Execute the test runner script to run all unit tests:
     ```bash
     ./run_tests.sh
     ```
   - Ensure that all tests pass.
