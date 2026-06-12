# A2UI Swift Core Agent Guide (AGENTS.md)

This document is the authoritative guide for AI agents working within the `renderers/swift_core` directory. It outlines the project structure and testing guidelines for the Swift core engine.

---

## 1. Project Structure

The Swift core library is structured as follows:
- **`Sources/A2UIJSON`**: Contains the core Swift logic to build, parse, and validate JSON schemas and common types.
- **`Tests/A2UIJSONTests`**: Contains the comprehensive unit test suite for the JSON schema builder, parser, and validator.
- **`Package.swift`** (located at the repository root): The SPM package definition managing products and targets. It is configured to strictly support **iOS** (`.iOS(.v16)`).

---

## 2. Running Tests

Since the Swift core package only supports iOS, running tests on macOS requires compiling and executing them on the iOS Simulator.

### Recommended Way (Automatic Script)
You can run the tests using the local test runner script situated in this directory:
```bash
./run_tests.sh
```
This script automatically:
1. Detects available iPhone simulator destinations on your macOS host.
2. Selects the first available iPhone simulator.
3. Executes the test suite targeting that simulator via `xcodebuild`.
4. Falls back to a simulator build check using `swift build` if no simulator device is booted or available.

### Manual Command
Alternatively, you can run the tests manually from the repository root:
```bash
xcodebuild test -scheme A2UISwiftCore -destination "platform=iOS Simulator,name=iPhone 16,OS=18.4"
```
*(Replace `name` and `OS` with an available simulator destination on your machine).*
