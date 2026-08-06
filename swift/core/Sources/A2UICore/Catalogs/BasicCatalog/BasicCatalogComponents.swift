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
import JSONSchema
import OrderedJSON

/// Component API definitions for all 18 standard components in the A2UI Basic Catalog.
public enum BasicCatalogComponents: Sendable {

  private static let remote = A2UICommonSchema.allSchemas

  // MARK: - Text
  public static let text: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "Text" },
            "text": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "variant": {
              "type": "string",
              "enum": ["h1", "h2", "h3", "h4", "h5", "caption", "body"],
              "default": "body"
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "text"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "Text", schema: schema)
  }()

  // MARK: - Image
  public static let image: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "Image" },
            "url": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "description": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "fit": {
              "type": "string",
              "enum": ["contain", "cover", "fill", "none", "scaleDown"],
              "default": "fill"
            },
            "variant": {
              "type": "string",
              "enum": ["icon", "avatar", "smallFeature", "mediumFeature", "largeFeature", "header"],
              "default": "mediumFeature"
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "url"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "Image", schema: schema)
  }()

  // MARK: - Icon
  public static let icon: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "Icon" },
            "name": {
              "oneOf": [
                { "type": "string" },
                {
                  "type": "object",
                  "properties": { "svgPath": { "type": "string" } },
                  "required": ["svgPath"]
                },
                { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DataBinding" }
              ]
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "name"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "Icon", schema: schema)
  }()

  // MARK: - Video
  public static let video: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "Video" },
            "url": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "url"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "Video", schema: schema)
  }()

  // MARK: - AudioPlayer
  public static let audioPlayer: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "AudioPlayer" },
            "url": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "description": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "url"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "AudioPlayer", schema: schema)
  }()

  // MARK: - Row
  public static let row: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "Row" },
            "children": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList" },
            "justify": {
              "type": "string",
              "enum": ["center", "end", "spaceAround", "spaceBetween", "spaceEvenly", "start", "stretch"],
              "default": "start"
            },
            "align": {
              "type": "string",
              "enum": ["start", "center", "end", "stretch"],
              "default": "stretch"
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "children"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "Row", schema: schema)
  }()

  // MARK: - Column
  public static let column: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "Column" },
            "children": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList" },
            "justify": {
              "type": "string",
              "enum": ["start", "center", "end", "spaceBetween", "spaceAround", "spaceEvenly", "stretch"],
              "default": "start"
            },
            "align": {
              "type": "string",
              "enum": ["center", "end", "start", "stretch"],
              "default": "stretch"
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "children"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "Column", schema: schema)
  }()

  // MARK: - List
  public static let list: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "List" },
            "children": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList" },
            "direction": {
              "type": "string",
              "enum": ["vertical", "horizontal"],
              "default": "vertical"
            },
            "align": {
              "type": "string",
              "enum": ["start", "center", "end", "stretch"],
              "default": "stretch"
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "children"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "List", schema: schema)
  }()

  // MARK: - Card
  public static let card: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "Card" },
            "child": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "child"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "Card", schema: schema)
  }()

  // MARK: - Tabs
  public static let tabs: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "Tabs" },
            "tabs": {
              "type": "array",
              "minItems": 1,
              "items": {
                "type": "object",
                "properties": {
                  "title": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
                  "child": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" }
                },
                "required": ["title", "child"]
              }
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "tabs"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "Tabs", schema: schema)
  }()

  // MARK: - Modal
  public static let modal: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "Modal" },
            "trigger": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "content": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "trigger", "content"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "Modal", schema: schema)
  }()

  // MARK: - Divider
  public static let divider: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "Divider" },
            "axis": {
              "type": "string",
              "enum": ["horizontal", "vertical"],
              "default": "horizontal"
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "Divider", schema: schema)
  }()

  // MARK: - Button
  public static let button: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "Button" },
            "child": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "variant": {
              "type": "string",
              "enum": ["default", "primary", "borderless"],
              "default": "default"
            },
            "action": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/Action" },
            "checks": {
              "type": "array",
              "items": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/CheckRule" }
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "child", "action"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "Button", schema: schema)
  }()

  // MARK: - TextField
  public static let textField: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "TextField" },
            "label": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "value": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "variant": {
              "type": "string",
              "enum": ["longText", "number", "shortText", "obscured"],
              "default": "shortText"
            },
            "validationRegexp": { "type": "string" },
            "checks": {
              "type": "array",
              "items": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/CheckRule" }
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "label"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "TextField", schema: schema)
  }()

  // MARK: - CheckBox
  public static let checkBox: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "CheckBox" },
            "label": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "value": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicBoolean" },
            "checks": {
              "type": "array",
              "items": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/CheckRule" }
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "label", "value"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "CheckBox", schema: schema)
  }()

  // MARK: - ChoicePicker
  public static let choicePicker: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "ChoicePicker" },
            "label": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "variant": {
              "type": "string",
              "enum": ["multipleSelection", "mutuallyExclusive"],
              "default": "mutuallyExclusive"
            },
            "options": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "label": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
                  "value": { "type": "string" }
                },
                "required": ["label", "value"]
              }
            },
            "value": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicStringList" },
            "displayStyle": {
              "type": "string",
              "enum": ["checkbox", "chips"],
              "default": "checkbox"
            },
            "filterable": { "type": "boolean", "default": false },
            "checks": {
              "type": "array",
              "items": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/CheckRule" }
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "options", "value"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "ChoicePicker", schema: schema)
  }()

  // MARK: - Slider
  public static let slider: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "Slider" },
            "label": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "min": { "type": "number", "default": 0 },
            "max": { "type": "number" },
            "value": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicNumber" },
            "checks": {
              "type": "array",
              "items": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/CheckRule" }
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "value", "max"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "Slider", schema: schema)
  }()

  // MARK: - DateTimeInput
  public static let dateTimeInput: ComponentAPI = {
    let schema = try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "id": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId" },
            "component": { "const": "DateTimeInput" },
            "value": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "enableDate": { "type": "boolean", "default": false },
            "enableTime": { "type": "boolean", "default": false },
            "min": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "max": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "label": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString" },
            "checks": {
              "type": "array",
              "items": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/CheckRule" }
            },
            "accessibility": { "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes" },
            "weight": { "type": "number" }
          },
          "required": ["component", "value"]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "DateTimeInput", schema: schema)
  }()

  // MARK: - All 18 Basic Components
  public static var allComponents: [ComponentAPI] {
    [
      text,
      image,
      icon,
      video,
      audioPlayer,
      row,
      column,
      list,
      card,
      tabs,
      modal,
      divider,
      button,
      textField,
      checkBox,
      choicePicker,
      slider,
      dateTimeInput,
    ]
  }
}
