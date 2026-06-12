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

import Testing
import Foundation
import A2UIJSON

struct BuilderTests {

  @Test
  func `DSL constructs a valid object schema`() throws {
    let schema = JSONSchema.object {
      JSONSchemaProperty.property("id") { JSONSchema.string() }
      JSONSchemaProperty.property("count") { JSONSchema.integer() }
      JSONSchemaProperty.property("isActive") { JSONSchema.boolean() }
      JSONSchemaProperty.property("items") {
        JSONSchema.array {
          JSONSchema.string()
        }
      }
    }

    let jsonString = try schema.print(
      bundleExternalRefs: false,
      sorting: SerializationSorting.alphabetical,
      prettyPrinted: true
    )

    let expected = ##"""
    {
      "properties" : {
        "count" : {
          "type" : "integer"
        },
        "id" : {
          "type" : "string"
        },
        "isActive" : {
          "type" : "boolean"
        },
        "items" : {
          "items" : {
            "type" : "string"
          },
          "type" : "array"
        }
      },
      "type" : "object"
    }
    """##
    #expect(jsonString == expected)
  }

  @Test
  func `Refs print as absolute URIs when bundling is disabled`() throws {
    let stub = JSONSchema.stub(
      uri: "https://a2ui.dev/schema/v1/component.json"
    )
    let schema = JSONSchema.object {
      JSONSchemaProperty.property("component") { JSONSchema.reference(stub) }
    }

    let jsonString = try schema.print(
      bundleExternalRefs: false,
      sorting: SerializationSorting.alphabetical,
      prettyPrinted: true
    )

    let expected = ##"""
    {
      "properties" : {
        "component" : {
          "$ref" : "https://a2ui.dev/schema/v1/component.json"
        }
      },
      "type" : "object"
    }
    """##
    #expect(jsonString == expected)
  }

  @Test
  func `Refs are bundled into defs when bundling is enabled`() throws {
    let stub = JSONSchema.stub(uri: "https://a2ui.dev/schema/v1/component.json") {
      JSONSchema.object {
        JSONSchemaProperty.property("id") { JSONSchema.string() }
      }
    }
    let schema = JSONSchema.object {
      JSONSchemaProperty.property("component") { JSONSchema.reference(stub) }
    }

    let jsonString = try schema.print(
      bundleExternalRefs: true,
      sorting: SerializationSorting.alphabetical,
      prettyPrinted: true
    )

    let expected = ##"""
    {
      "$defs" : {
        "component" : {
          "$id" : "https://a2ui.dev/schema/v1/component.json",
          "properties" : {
            "id" : {
              "type" : "string"
            }
          },
          "type" : "object"
        }
      },
      "properties" : {
        "component" : {
          "$ref" : "#/$defs/component"
        }
      },
      "type" : "object"
    }
    """##
    #expect(jsonString == expected)
  }


  @Test
  func `Required properties are serialized into required array`() throws {
    let schema = JSONSchema.object {
      JSONSchemaProperty.property("id", isRequired: true) { JSONSchema.string() }
      JSONSchemaProperty.property("name") { JSONSchema.string() }
    }

    let jsonString = try schema.print(
      bundleExternalRefs: false,
      sorting: SerializationSorting.alphabetical,
      prettyPrinted: true
    )

    let expected = ##"""
    {
      "properties" : {
        "id" : {
          "type" : "string"
        },
        "name" : {
          "type" : "string"
        }
      },
      "required" : [
        "id"
      ],
      "type" : "object"
    }
    """##
    #expect(jsonString == expected)
  }

  @Test
  func `Tracker resolves collisions by appending counter`() throws {
    let stub1 = JSONSchema.stub(
      uri: "https://a2ui.dev/schema/v1/component.json"
    )
    let stub2 = JSONSchema.stub(
      uri: "https://a2ui.dev/schema/v2/component.json"
    )
    let schema = JSONSchema.object {
      JSONSchemaProperty.property("comp1") { JSONSchema.reference(stub1) }
      JSONSchemaProperty.property("comp2") { JSONSchema.reference(stub2) }
    }

    let jsonString = try schema.print(
      bundleExternalRefs: true,
      sorting: SerializationSorting.alphabetical,
      prettyPrinted: true
    )

    let expected = ##"""
    {
      "$defs" : {
        "component" : {
          "$id" : "https://a2ui.dev/schema/v1/component.json",
          "type" : "object"
        },
        "component1" : {
          "$id" : "https://a2ui.dev/schema/v2/component.json",
          "type" : "object"
        }
      },
      "properties" : {
        "comp1" : {
          "$ref" : "#/$defs/component"
        },
        "comp2" : {
          "$ref" : "#/$defs/component1"
        }
      },
      "type" : "object"
    }
    """##
    #expect(jsonString == expected)
  }

  @Test
  func `SchemaNumber serializes to number type`() throws {
    let schema = JSONSchema.object {
      JSONSchemaProperty.property("ratio") { JSONSchema.number() }
    }

    let jsonString = try schema.print(
      bundleExternalRefs: false,
      sorting: SerializationSorting.alphabetical,
      prettyPrinted: false
    )

    let expected =
      #"{"properties":{"ratio":{"type":"number"}},"type":"object"}"#
    #expect(jsonString == expected)
  }

  @Test
  func testFluentDependenciesDSL() throws {
    let schema = JSONSchema.object {
      JSONSchemaProperty.property("creditCard") { JSONSchema.number() }
      JSONSchemaProperty.property("billingAddress") { JSONSchema.string() }
    }
    .dependencies {
      JSONSchemaDependency.dependency("creditCard", keys: ["billingAddress"])
    }

    let jsonString = try schema.print(
      bundleExternalRefs: false,
      sorting: SerializationSorting.alphabetical,
      prettyPrinted: true
    )

    let expected = ##"""
    {
      "dependencies" : {
        "creditCard" : [
          "billingAddress"
        ]
      },
      "properties" : {
        "billingAddress" : {
          "type" : "string"
        },
        "creditCard" : {
          "type" : "number"
        }
      },
      "type" : "object"
    }
    """##
    #expect(jsonString == expected)

    let validInstance = JSONValue.object([
      "creditCard": .number(123456),
      "billingAddress": .string("123 Main St")
    ])
    #expect(throws: Never.self) {
      try schema.validate(instance: validInstance)
    }

    let invalidInstance = JSONValue.object([
      "creditCard": .number(123456)
    ])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalidInstance)
    }
  }

  @Test
  func testFluentPatternPropertiesDSL() throws {
    let schema = JSONSchema.object()
      .patternProperties {
        JSONSchemaPatternProperty.pattern("^S_", JSONSchema.string())
        JSONSchemaPatternProperty.pattern("^I_", JSONSchema.integer())
      }

    let jsonString = try schema.print(
      bundleExternalRefs: false,
      sorting: SerializationSorting.alphabetical,
      prettyPrinted: true
    )

    let expected = ##"""
    {
      "patternProperties" : {
        "^I_" : {
          "type" : "integer"
        },
        "^S_" : {
          "type" : "string"
        }
      },
      "type" : "object"
    }
    """##
    #expect(jsonString == expected)

    let validInstance = JSONValue.object([
      "S_name": .string("Alice"),
      "I_age": .number(30)
    ])
    #expect(throws: Never.self) {
      try schema.validate(instance: validInstance)
    }

    let invalidInstance = JSONValue.object([
      "S_name": .number(123)
    ])
    #expect(throws: ValidationError.self) {
      try schema.validate(instance: invalidInstance)
    }
  }
}
