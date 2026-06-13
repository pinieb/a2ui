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

import A2UIJSON
import Foundation
import Testing

@Suite(.serialized)
struct A2UICommonSchemaTests {

  @Test
  func `A2UICommonSchema compiles and serializes without errors`() throws {
    let schemas = [
      A2UICommonSchema.componentID,
      A2UICommonSchema.accessibilityAttributes,
      A2UICommonSchema.componentCommon,
      A2UICommonSchema.childList,
      A2UICommonSchema.dataBinding,
      A2UICommonSchema.dynamicValue,
      A2UICommonSchema.dynamicString,
      A2UICommonSchema.dynamicNumber,
      A2UICommonSchema.dynamicBoolean,
      A2UICommonSchema.dynamicStringList,
      A2UICommonSchema.functionCall,
      A2UICommonSchema.checkRule,
      A2UICommonSchema.checkable,
      A2UICommonSchema.action,
    ]

    for schema in schemas {
      let wrapper = JSONSchema.object {
        JSONSchemaProperty.property("root") { schema }
      }
      let printed = try wrapper.print(
        bundleExternalRefs: false,
        sorting: .alphabetical,
        prettyPrinted: false
      )
      #expect(!printed.isEmpty)
    }
  }

  @Test
  func `Transitive bundling resolves and encodes deep reference chains`()
    throws
  {
    let schema = JSONSchema.object {
      JSONSchemaProperty.property("common") {
        JSONSchema.reference(A2UICommonSchema.componentCommon)
      }
    }

    let jsonString = try schema.print(
      bundleExternalRefs: true,
      sorting: .alphabetical,
      prettyPrinted: true
    )

    let expected =
      ("{\n"
        + "  \"$defs\" : {\n"
        + "    \"AccessibilityAttributesSchema\" : {\n"
        + "      \"$id\" : \"https://a2ui.dev/schema/v0.9.1/common/"
        + "AccessibilityAttributesSchema.json\",\n"
        + "      \"properties\" : {\n"
        + "        \"description\" : {\n"
        + "          \"$ref\" : \"#/$defs/DynamicStringSchema\"\n"
        + "        },\n"
        + "        \"label\" : {\n"
        + "          \"$ref\" : \"#/$defs/DynamicStringSchema\"\n"
        + "        }\n"
        + "      },\n"
        + "      \"type\" : \"object\"\n"
        + "    },\n"
        + "    \"ComponentCommonSchema\" : {\n"
        + "      \"$id\" : \"https://a2ui.dev/schema/v0.9.1/common/"
        + "ComponentCommonSchema.json\",\n"
        + "      \"properties\" : {\n"
        + "        \"accessibility\" : {\n"
        + "          \"$ref\" : \"#/$defs/AccessibilityAttributesSchema\"\n"
        + "        },\n"
        + "        \"id\" : {\n"
        + "          \"$ref\" : \"#/$defs/ComponentIDSchema\"\n"
        + "        }\n"
        + "      },\n"
        + "      \"required\" : [\n"
        + "        \"id\"\n"
        + "      ],\n"
        + "      \"type\" : \"object\"\n"
        + "    },\n"
        + "    \"ComponentIDSchema\" : {\n"
        + "      \"$id\" : \"https://a2ui.dev/schema/v0.9.1/common/"
        + "ComponentIDSchema.json\",\n"
        + "      \"type\" : \"string\"\n"
        + "    },\n"
        + "    \"DataBindingSchema\" : {\n"
        + "      \"$id\" : \"https://a2ui.dev/schema/v0.9.1/common/"
        + "DataBindingSchema.json\",\n"
        + "      \"additionalProperties\" : false,\n"
        + "      \"properties\" : {\n"
        + "        \"path\" : {\n"
        + "          \"type\" : \"string\"\n"
        + "        }\n"
        + "      },\n"
        + "      \"required\" : [\n"
        + "        \"path\"\n"
        + "      ],\n"
        + "      \"type\" : \"object\"\n"
        + "    },\n"
        + "    \"DynamicStringSchema\" : {\n"
        + "      \"$id\" : \"https://a2ui.dev/schema/v0.9.1/common/"
        + "DynamicStringSchema.json\",\n"
        + "      \"anyOf\" : [\n"
        + "        {\n"
        + "          \"type\" : \"string\"\n"
        + "        },\n"
        + "        {\n"
        + "          \"$ref\" : \"#/$defs/DataBindingSchema\"\n"
        + "        },\n"
        + "        {\n"
        + "          \"allOf\" : [\n"
        + "            {\n"
        + "              \"$ref\" : \"#/$defs/FunctionCallSchema\"\n"
        + "            },\n"
        + "            {\n"
        + "              \"properties\" : {\n"
        + "                \"returnType\" : {\n"
        + "                  \"const\" : \"string\"\n"
        + "                }\n"
        + "              },\n"
        + "              \"type\" : \"object\"\n"
        + "            }\n"
        + "          ]\n"
        + "        }\n"
        + "      ]\n"
        + "    },\n"
        + "    \"DynamicValueSchema\" : {\n"
        + "      \"$id\" : \"https://a2ui.dev/schema/v0.9.1/common/"
        + "DynamicValueSchema.json\",\n"
        + "      \"anyOf\" : [\n"
        + "        {\n"
        + "          \"type\" : \"string\"\n"
        + "        },\n"
        + "        {\n"
        + "          \"type\" : \"number\"\n"
        + "        },\n"
        + "        {\n"
        + "          \"type\" : \"boolean\"\n"
        + "        },\n"
        + "        {\n"
        + "          \"type\" : \"array\"\n"
        + "        },\n"
        + "        {\n"
        + "          \"$ref\" : \"#/$defs/DataBindingSchema\"\n"
        + "        },\n"
        + "        {\n"
        + "          \"$ref\" : \"#/$defs/FunctionCallSchema\"\n"
        + "        }\n"
        + "      ]\n"
        + "    },\n"
        + "    \"FunctionCallSchema\" : {\n"
        + "      \"$id\" : \"https://a2ui.dev/schema/v0.9.1/common/"
        + "FunctionCallSchema.json\",\n"
        + "      \"properties\" : {\n"
        + "        \"args\" : {\n"
        + "          \"additionalProperties\" : {\n"
        + "            \"anyOf\" : [\n"
        + "              {\n"
        + "                \"$ref\" : \"#/$defs/DynamicValueSchema\"\n"
        + "              },\n"
        + "              {\n"
        + "                \"type\" : \"object\"\n"
        + "              }\n"
        + "            ]\n"
        + "          },\n"
        + "          \"type\" : \"object\"\n"
        + "        },\n"
        + "        \"call\" : {\n"
        + "          \"type\" : \"string\"\n"
        + "        },\n"
        + "        \"returnType\" : {\n"
        + "          \"type\" : \"string\"\n"
        + "        }\n"
        + "      },\n"
        + "      \"required\" : [\n"
        + "        \"call\"\n"
        + "      ],\n"
        + "      \"type\" : \"object\"\n"
        + "    }\n"
        + "  },\n"
        + "  \"properties\" : {\n"
        + "    \"common\" : {\n"
        + "      \"$ref\" : \"#/$defs/ComponentCommonSchema\"\n"
        + "    }\n"
        + "  },\n"
        + "  \"type\" : \"object\"\n"
        + "}")

    #expect(jsonString == expected)
  }

  @Test
  func `DynamicStringSchema validates literal strings and data bindings`()
    throws
  {
    _ = try A2UICommonSchema.dynamicString.validate(instance: .string("hello"))

    _ = try A2UICommonSchema.dynamicString.validate(
      instance: .object(["path": .string("/user/name")])
    )

    do {
      _ = try A2UICommonSchema.dynamicString.validate(instance: .number(123))
      Issue.record("Expected ValidationError but none was thrown")
    } catch let error as ValidationError {
      #expect(error.path == "/")
      #expect(
        error.message.contains("Expected type") || error.message.contains("match")
      )
    } catch {
      Issue.record("Expected ValidationError but got \(error)")
    }
  }

  @Test
  func `ActionSchema validates server events and client function calls`()
    throws
  {
    let event = JSONValue.object([
      "event": .object([
        "name": .string("click"),
        "context": .object(["userID": .string("123")]),
      ])
    ])
    _ = try A2UICommonSchema.action.validate(instance: event)

    let invalidEvent = JSONValue.object([
      "event": .object([
        "context": .object([:])
      ])
    ])

    do {
      _ = try A2UICommonSchema.action.validate(instance: invalidEvent)
      Issue.record("Expected ValidationError but none was thrown")
    } catch let error as ValidationError {
      #expect(error.path == "/event")
      #expect(error.message.contains("missing"))
      #expect(error.message.contains("name"))
    } catch {
      Issue.record("Expected ValidationError but got \(error)")
    }
  }

  @Test
  func `DynamicValueSchema validates generic arrays`() throws {
    _ = try A2UICommonSchema.dynamicValue.validate(
      instance: .array([.number(1), .number(2)])
    )
  }
}
