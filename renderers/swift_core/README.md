# A2UI Swift Core Engine

A platform-agnostic, high-performance Swift library for building, parsing, and validating
JSON Schema Draft 2020-12 and A2UI common type schemas. Supports iOS (`.iOS(.v16)`) and
macOS (`.macOS(.v13)`).

---

## Target Architecture

The Swift Core package is divided into two distinct modular targets to separate generic JSON Schema
infrastructure from A2UI-specific logic:

1. **`JSONSchema`**:
   * A completely generic, self-contained implementation of the JSON Schema Draft 2020-12
     specification.
   * Includes a thread-safe registry, a lexical scope resolver, validation outputs, and a
     declarative Swift-native DSL.
   * Has absolutely no dependencies on A2UI.

2. **`A2UIJSON`**:
   * Contains the A2UI-specific common type schemas (such as `ActionSchema`, `DataBindingSchema`,
     `DynamicValueSchema`, and `ComponentCommonSchema`).
   * Depends directly on `JSONSchema` to define and validate these schemas.

3. **`A2UICore`**:
   * The stateful runtime core engine implementing the A2UI state machine, validation pipeline,
     and bidirectional event routing.
   * Leverages `MessageProcessor` to parse streaming JSONL packets, validate them against the
     catalog schemas, and route structured error events (`ClientServerError`) to the host.
   * Utilizes `SurfaceViewModel` to buffer active components, resolve two-way state bindings,
     and publish the resolved UI node tree.
   * Depends directly on both `A2UIJSON` and `JSONSchema`.


---

## Integration

To integrate A2UI Swift Core into your Swift Package, add it to your `Package.swift` dependencies:

```swift
dependencies: [
  .package(name: "A2UISwiftCore", path: "path/to/a2ui/renderers/swift_core")
]
```

Then add the target products to your target's dependencies:

```swift
targets: [
  .target(
    name: "MyTarget",
    dependencies: [
      .product(name: "A2UISwiftCore", package: "A2UISwiftCore")
    ]
  )
]
```

In your Swift source files, import the targets you need:

```swift
import JSONSchema // For generic JSON Schema builder & validator
import A2UIJSON   // For A2UI-specific common type schemas
import A2UICore   // For stateful core engine (SurfaceViewModel, etc.)
```

---

## Quick Start Examples

### 1. Declaring a Schema using the Swift DSL
Use our declarative, Result Builder-based DSL to define schemas cleanly in native Swift code:

```swift
import JSONSchema

let userSchema = JSONSchema.object {
  JSONSchemaProperty.property("id", isRequired: true) {
    JSONSchema.integer()
  }
  JSONSchemaProperty.property("name", isRequired: true) {
    JSONSchema.string()
  }
  JSONSchemaProperty.property("email") {
    JSONSchema.string().format("email")
  }
}
```

### 2. Validating JSON Instances
Validate generic `JSONValue` instances against your schema and catch detailed validation errors:

```swift
import JSONSchema

let validUser = JSONValue.object([
  "id": .number(42),
  "name": .string("Alice"),
  "email": .string("alice@example.com")
])

do {
  let output = try userSchema.validate(instance: validUser)
  print("Validation succeeded! Matched Schema IDs: \(output.matchedSchemaIDs)")
} catch let error as ValidationError {
  print("Validation failed at path '\(error.path)': \(error.message)")
}
```

### 3. Using A2UI Common Schemas
Leverage pre-defined A2UI common schemas to validate streaming UI payloads:

```swift
import JSONSchema
import A2UIJSON

let eventPayload = JSONValue.object([
  "event": .object([
    "name": .string("click"),
    "context": .object(["userID": .string("123")])
  ])
])

do {
  _ = try A2UICommonSchema.action.validate(instance: eventPayload)
  print("A2UI Action payload is valid!")
} catch {
  print("Invalid Action payload: \(error)")
}
```

---

## Next Steps

* For build, test, formatting, and Bowtie conformance instructions, see
  [DEVELOPMENT.md](DEVELOPMENT.md).
* For internal design, Result Builders, and lexical scope resolution details, see
  [ARCHITECTURE.md](ARCHITECTURE.md).
* For AI agent rules of engagement, see
  [AGENTS.md](AGENTS.md).
