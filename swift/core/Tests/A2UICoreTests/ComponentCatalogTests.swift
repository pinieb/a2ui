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

import A2UICore
import A2UIJSON
import JSONSchema
import OrderedJSON
import Testing

/// A concrete `LocalFunction` for testing that concatenates string
/// arguments.
struct ConcatFunction: LocalFunction {
  func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    let first = arguments["a"]?.stringValue ?? ""
    let second = arguments["b"]?.stringValue ?? ""
    return .string(first + second)
  }
}

/// A concrete `LocalFunction` for testing that returns a boolean.
struct IsEmptyFunction: LocalFunction {
  func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    let value = arguments["value"]?.stringValue ?? ""
    return .boolean(value.isEmpty)
  }
}

/// A concrete `SurfaceTheme` for testing.
struct TestTheme: SurfaceTheme {
  let primaryColor: String
  let fontSize: Double
}

/// A concrete `ComponentCatalog` for testing.
struct TestCatalog: ComponentCatalog {
  let schemas: [String: Schema]
  let functions: [String: any LocalFunction]

  init(schemas: [String: Schema] = [:], functions: [String: any LocalFunction] = [:]) {
    self.schemas = schemas
    self.functions = functions
  }

  func schema(forType type: String) -> Schema? {
    schemas[type]
  }

  func makeTheme(jsonObject: JSONValue) -> (any SurfaceTheme)? {
    guard let dict = jsonObject.dictionaryValue else { return nil }
    return TestTheme(
      primaryColor: dict["primaryColor"]?.stringValue ?? "black",
      fontSize: dict["fontSize"]?.doubleValue ?? 14.0
    )
  }

  func localFunction(for name: String) -> (any LocalFunction)? {
    functions[name]
  }
}

struct ComponentCatalogTests {

  // MARK: - Schema Lookup

  @Test func schemaLookupReturnsSchemaForRegisteredType() throws {
    let schema = try Schema(
      instance: """
        {"type": "object", "properties": {"id": {"type": "string"}}}
        """
    )
    let catalog = TestCatalog(schemas: ["button": schema])

    let result = catalog.schema(forType: "button")
    #expect(result != nil)
  }

  @Test func schemaLookupReturnsNilForUnregisteredType() {
    let catalog = TestCatalog()
    #expect(catalog.schema(forType: "unknown") == nil)
  }

  // MARK: - Theme Parsing

  @Test func makeThemeParsesValidTheme() {
    let catalog = TestCatalog()
    let themeJson: JSONValue = [
      "primaryColor": "blue",
      "fontSize": 16.0,
    ]
    let theme = catalog.makeTheme(jsonObject: themeJson)
    #expect(theme != nil)
    if let testTheme = theme as? TestTheme {
      #expect(testTheme.primaryColor == "blue")
      #expect(testTheme.fontSize == 16.0)
    }
  }

  @Test func makeThemeReturnsNilForNonObject() {
    let catalog = TestCatalog()
    let theme = catalog.makeTheme(jsonObject: "not an object")
    #expect(theme == nil)
  }

  @Test func makeThemeUsesDefaultsForMissingKeys() {
    let catalog = TestCatalog()
    let themeJson: JSONValue = JSONValue.object([:])
    let theme = catalog.makeTheme(jsonObject: themeJson) as? TestTheme
    #expect(theme?.primaryColor == "black")
    #expect(theme?.fontSize == 14.0)
  }

  // MARK: - Local Function Lookup

  @Test func localFunctionReturnsRegisteredFunction() {
    let catalog = TestCatalog(
      functions: ["concat": ConcatFunction(), "isEmpty": IsEmptyFunction()]
    )
    let fn = catalog.localFunction(for: "concat")
    #expect(fn != nil)
  }

  @Test func localFunctionReturnsNilForUnregistered() {
    let catalog = TestCatalog()
    #expect(catalog.localFunction(for: "unknown") == nil)
  }

  @Test func localFunctionEvaluatesCorrectly() throws {
    let catalog = TestCatalog(
      functions: ["concat": ConcatFunction()]
    )
    let fn = try #require(catalog.localFunction(for: "concat"))
    let result = try fn.evaluate(arguments: ["a": "Hello, ", "b": "World!"])
    #expect(result.stringValue == "Hello, World!")
  }

  @Test func localFunctionEvaluatesBooleanResult() throws {
    let catalog = TestCatalog(
      functions: ["isEmpty": IsEmptyFunction()]
    )
    let fn = try #require(catalog.localFunction(for: "isEmpty"))
    let result = try fn.evaluate(arguments: ["value": ""])
    #expect(result.boolValue == true)

    let result2 = try fn.evaluate(arguments: ["value": "hello"])
    #expect(result2.boolValue == false)
  }
}

struct FunctionRegistryTests {

  // MARK: - LocalFunction Protocol

  @Test func concatFunctionEvaluatesWithBothArgs() throws {
    let fn = ConcatFunction()
    let result = try fn.evaluate(arguments: [
      "a": "Hello, ",
      "b": "World!",
    ])
    #expect(result.stringValue == "Hello, World!")
  }

  @Test func concatFunctionHandlesMissingArgs() throws {
    let fn = ConcatFunction()
    let result = try fn.evaluate(arguments: [:])
    #expect(result.stringValue == "")
  }

  @Test func isEmptyFunctionReturnsTrueForEmptyString() throws {
    let fn = IsEmptyFunction()
    let result = try fn.evaluate(arguments: ["value": ""])
    #expect(result.boolValue == true)
  }

  @Test func isEmptyFunctionReturnsFalseForNonEmptyString() throws {
    let fn = IsEmptyFunction()
    let result = try fn.evaluate(arguments: ["value": "hello"])
    #expect(result.boolValue == false)
  }

  @Test func isEmptyFunctionReturnsTrueForMissingArg() throws {
    let fn = IsEmptyFunction()
    let result = try fn.evaluate(arguments: [:])
    #expect(result.boolValue == true)
  }
}
