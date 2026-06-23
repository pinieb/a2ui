# JSONSchema

A generic Swift implementation of a JSON Schema Draft 2020-12 validator and domain-specific
language (DSL) builder.

> [!IMPORTANT]
> **Boundary Rule**: This target is generic, independent, and specification-compliant.
> Never introduce A2UI-specific types, schemas, event validations, or tests here.

---

## Key Core Types

- **[JSONValue](Sources/JSONValue.swift)**: Represents any valid JSON value (`null`, `boolean`,
  `number`, `string`, `array`, `object`) conforming to `Codable`, `Sendable`, and `Equatable`.
- **[JSONPointer](Sources/JSONPointer.swift)**: Implements RFC 6901 JSON Pointer for path-based indexing
  into a `JSONValue` structure.
- **[SchemaNode](Sources/SchemaNode.swift)**: Represents a compiled schema node. It evaluates a
  `JSONValue` instance using a collection of registered keyword evaluators.
- **[KeywordEvaluator](Sources/KeywordEvaluator.swift)**: A protocol implemented by evaluators for
  individual JSON Schema keywords (e.g., `type`, `properties`, `required`).
- **[ValidationContext](Sources/ValidationContext.swift)**: Tracks recursion depth and path locations
  during a validation run to enforce configuration limits (such as max evaluation depth).

---

## Defining a Custom Keyword Evaluator

To implement custom validation logic, conform to the `KeywordEvaluator` protocol:

```swift
import JSONSchema

struct MinLengthEvaluator: KeywordEvaluator {
  let minLength: Int

  func evaluate(instance: JSONValue, context: ValidationContext) -> ValidationResult {
    guard case .string(let text) = instance else {
      // Ignore validation if the type is not a string (standard JSON Schema behavior).
      return .success()
    }

    if text.count >= minLength {
      return .success()
    } else {
      return .failure(error: "String length must be at least \(minLength) characters.")
    }
  }
}
```

---

## Running Validation

Compile evaluators into a `SchemaNode` and run the validation pass:

```swift
import JSONSchema

// 1. Define a schema node with evaluators
let minLengthNode = SchemaNode(
  identity: SchemaIdentity(baseURI: "https://example.com/min-length-schema"),
  evaluators: [MinLengthEvaluator(minLength: 5)]
)

// 2. Prepare validation context and input data
let context = ValidationContext()
let validInstance = JSONValue.string("A2UI Standard")
let invalidInstance = JSONValue.string("Mini")

// 3. Evaluate inputs
let result1 = minLengthNode.evaluate(instance: validInstance, context: context)
print("Result 1: \(result1.isValid)") // Output: true

let result2 = minLengthNode.evaluate(instance: invalidInstance, context: context)
print("Result 2: \(result2.isValid)") // Output: false
print("Errors: \(result2.errors)")    // Output: ["String length must be at least 5..."]
```
