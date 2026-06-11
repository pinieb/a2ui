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
    let schema = SchemaObject {
      SchemaProperty(name: "id", type: SchemaString())
      SchemaProperty(name: "count", type: SchemaInteger())
      SchemaProperty(name: "isActive", type: SchemaBoolean())
      SchemaProperty(
        name: "items",
        type: SchemaArray(items: SchemaString())
      )
    }

    let jsonString = try schema.print(
      bundleExternalRefs: false,
      sorting: .alphabetical,
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
    let stub = ExternalSchemaStub(
      uri: "https://a2ui.dev/schema/v1/component.json"
    )
    let schema = SchemaObject {
      SchemaProperty(name: "component", type: SchemaReference(stub))
    }

    let jsonString = try schema.print(
      bundleExternalRefs: false,
      sorting: .alphabetical,
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
    let stub = ExternalSchemaStub(
      uri: "https://a2ui.dev/schema/v1/component.json"
    )
    let schema = SchemaObject {
      SchemaProperty(name: "component", type: SchemaReference(stub))
    }

    let jsonString = try schema.print(
      bundleExternalRefs: true,
      sorting: .alphabetical,
      prettyPrinted: true
    )

    let expected = ##"""
    {
      "$defs" : {
        "component" : {
          "$id" : "https://a2ui.dev/schema/v1/component.json"
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
    let schema = SchemaObject {
      SchemaProperty(name: "id", type: SchemaString(), isRequired: true)
      SchemaProperty(name: "name", type: SchemaString())
    }

    let jsonString = try schema.print(
      bundleExternalRefs: false,
      sorting: .alphabetical,
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
    let stub1 = ExternalSchemaStub(
      uri: "https://a2ui.dev/schema/v1/component.json"
    )
    let stub2 = ExternalSchemaStub(
      uri: "https://a2ui.dev/schema/v2/component.json"
    )
    let schema = SchemaObject {
      SchemaProperty(name: "comp1", type: SchemaReference(stub1))
      SchemaProperty(name: "comp2", type: SchemaReference(stub2))
    }

    let jsonString = try schema.print(
      bundleExternalRefs: true,
      sorting: .alphabetical,
      prettyPrinted: true
    )

    let expected = ##"""
    {
      "$defs" : {
        "component" : {
          "$id" : "https://a2ui.dev/schema/v1/component.json"
        },
        "component1" : {
          "$id" : "https://a2ui.dev/schema/v2/component.json"
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
    let schema = SchemaObject {
      SchemaProperty(name: "ratio", type: SchemaNumber())
    }

    let jsonString = try schema.print(
      bundleExternalRefs: false,
      sorting: .alphabetical,
      prettyPrinted: false
    )

    let expected =
      #"{"properties":{"ratio":{"type":"number"}},"type":"object"}"#
    #expect(jsonString == expected)
  }
}

