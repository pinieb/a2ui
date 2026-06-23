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

public typealias EvaluatorFactory =
  @Sendable (
    _ data: JSONValue,
    _ identity: SchemaIdentity,
    _ compiler: SchemaCompiler
  ) throws -> any KeywordEvaluator

/// An extensibility engine mapping string keywords to evaluator factories.
public struct KeywordRegistry: Sendable {
  private var factories: [String: EvaluatorFactory] = [:]

  public init() {}

  public mutating func register(keyword: String, factory: @escaping EvaluatorFactory) {
    factories[keyword] = factory
  }

  public func makeEvaluator(
    for keyword: String,
    data: JSONValue,
    identity: SchemaIdentity,
    compiler: SchemaCompiler
  ) throws -> (any KeywordEvaluator)? {
    guard let factory = factories[keyword] else {
      return nil
    }
    return try factory(data, identity, compiler)
  }
}

extension KeywordRegistry {
  /// A default KeywordRegistry pre-configured with all core JSON Schema keywords.
  public static var `default`: KeywordRegistry {
    var registry = KeywordRegistry()
    registry.registerCoreKeywords()
    return registry
  }

  /// Registers all core validation keywords into this registry.
  public mutating func registerCoreKeywords() {
    register(keyword: "type") { data, _, _ in
      TypeEvaluator(allowedTypes: data)
    }
    register(keyword: "const") { data, _, _ in
      ConstEvaluator(expectedValue: data)
    }
    register(keyword: "enum") { data, _, _ in
      EnumEvaluator(allowedValues: data)
    }
    register(keyword: "multipleOf") { data, _, _ in
      MultipleOfEvaluator(divisor: data)
    }
    register(keyword: "maximum") { data, _, _ in
      MaximumEvaluator(limit: data)
    }
    register(keyword: "exclusiveMaximum") { data, _, _ in
      ExclusiveMaximumEvaluator(limit: data)
    }
    register(keyword: "minimum") { data, _, _ in
      MinimumEvaluator(limit: data)
    }
    register(keyword: "exclusiveMinimum") { data, _, _ in
      ExclusiveMinimumEvaluator(limit: data)
    }
  }
}
