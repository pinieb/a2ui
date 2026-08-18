// Copyright 2024 Google LLC
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
            "component": {
              "const": "Text"
            },
            "text": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString",
              "description": "The text content to display. While simple Markdown formatting is supported (i.e. without HTML, images, or links), utilizing dedicated UI components is generally preferred for a richer and more structured presentation."
            },
            "variant": {
              "type": "string",
              "description": "A hint for the base text style.",
              "enum": [
                "h1",
                "h2",
                "h3",
                "h4",
                "h5",
                "caption",
                "body"
              ],
              "default": "body"
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "text"
          ]
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
            "component": {
              "const": "Image"
            },
            "url": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString",
              "description": "The URL of the image to display."
            },
            "description": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString",
              "description": "Accessibility text for the image."
            },
            "fit": {
              "type": "string",
              "description": "Specifies how the image should be resized to fit its container. This corresponds to the CSS 'object-fit' property.",
              "enum": [
                "contain",
                "cover",
                "fill",
                "none",
                "scaleDown"
              ],
              "default": "fill"
            },
            "variant": {
              "type": "string",
              "description": "A hint for the image size and style.",
              "enum": [
                "icon",
                "avatar",
                "smallFeature",
                "mediumFeature",
                "largeFeature",
                "header"
              ],
              "default": "mediumFeature"
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "url"
          ]
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
            "component": {
              "const": "Icon"
            },
            "name": {
              "description": "The name of the icon to display.",
              "oneOf": [
                {
                  "type": "string",
                  "enum": [
                    "accountCircle",
                    "add",
                    "arrowBack",
                    "arrowForward",
                    "attachFile",
                    "calendarToday",
                    "call",
                    "camera",
                    "check",
                    "close",
                    "delete",
                    "download",
                    "edit",
                    "event",
                    "error",
                    "fastForward",
                    "favorite",
                    "favoriteOff",
                    "folder",
                    "help",
                    "home",
                    "info",
                    "locationOn",
                    "lock",
                    "lockOpen",
                    "mail",
                    "menu",
                    "moreVert",
                    "moreHoriz",
                    "notificationsOff",
                    "notifications",
                    "pause",
                    "payment",
                    "person",
                    "phone",
                    "photo",
                    "play",
                    "print",
                    "refresh",
                    "rewind",
                    "search",
                    "send",
                    "settings",
                    "share",
                    "shoppingCart",
                    "skipNext",
                    "skipPrevious",
                    "star",
                    "starHalf",
                    "starOff",
                    "stop",
                    "upload",
                    "visibility",
                    "visibilityOff",
                    "volumeDown",
                    "volumeMute",
                    "volumeOff",
                    "volumeUp",
                    "warning"
                  ]
                },
                {
                  "type": "object",
                  "properties": {
                    "svgPath": {
                      "type": "string"
                    }
                  },
                  "required": [
                    "svgPath"
                  ],
                  "additionalProperties": false
                },
                {
                  "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DataBinding"
                }
              ]
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "name"
          ]
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
            "component": {
              "const": "Video"
            },
            "url": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString",
              "description": "The URL of the video to display."
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "url"
          ]
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
            "component": {
              "const": "AudioPlayer"
            },
            "url": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString",
              "description": "The URL of the audio to be played."
            },
            "description": {
              "description": "A description of the audio, such as a title or summary.",
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "url"
          ]
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
            "component": {
              "const": "Row"
            },
            "children": {
              "description": "Defines the children. Use an array of strings for a fixed set of children, or a template object to generate children from a data list. Children cannot be defined inline, they must be referred to by ID.",
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList"
            },
            "justify": {
              "type": "string",
              "description": "Defines the arrangement of children along the main axis (horizontally). Use 'spaceBetween' to push items to the edges, or 'start'/'end'/'center' to pack them together.",
              "enum": [
                "center",
                "end",
                "spaceAround",
                "spaceBetween",
                "spaceEvenly",
                "start",
                "stretch"
              ],
              "default": "start"
            },
            "align": {
              "type": "string",
              "description": "Defines the alignment of children along the cross axis (vertically). This is similar to the CSS 'align-items' property, but uses camelCase values (e.g., 'start').",
              "enum": [
                "start",
                "center",
                "end",
                "stretch"
              ],
              "default": "stretch"
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "children"
          ]
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
            "component": {
              "const": "Column"
            },
            "children": {
              "description": "Defines the children. Use an array of strings for a fixed set of children, or a template object to generate children from a data list. Children cannot be defined inline, they must be referred to by ID.",
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList"
            },
            "justify": {
              "type": "string",
              "description": "Defines the arrangement of children along the main axis (vertically). Use 'spaceBetween' to push items to the edges (e.g. header at top, footer at bottom), or 'start'/'end'/'center' to pack them together.",
              "enum": [
                "start",
                "center",
                "end",
                "spaceBetween",
                "spaceAround",
                "spaceEvenly",
                "stretch"
              ],
              "default": "start"
            },
            "align": {
              "type": "string",
              "description": "Defines the alignment of children along the cross axis (horizontally). This is similar to the CSS 'align-items' property.",
              "enum": [
                "center",
                "end",
                "start",
                "stretch"
              ],
              "default": "stretch"
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "children"
          ]
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
            "component": {
              "const": "List"
            },
            "children": {
              "description": "Defines the children. Use an array of strings for a fixed set of children, or a template object to generate children from a data list.",
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ChildList"
            },
            "direction": {
              "type": "string",
              "description": "The direction in which the list items are laid out.",
              "enum": [
                "vertical",
                "horizontal"
              ],
              "default": "vertical"
            },
            "align": {
              "type": "string",
              "description": "Defines the alignment of children along the cross axis.",
              "enum": [
                "start",
                "center",
                "end",
                "stretch"
              ],
              "default": "stretch"
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "children"
          ]
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
            "component": {
              "const": "Card"
            },
            "child": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId",
              "description": "The ID of the single child component to be rendered inside the card. To display multiple elements, you MUST wrap them in a layout component (like Column or Row) and pass that container's ID here. Do NOT pass multiple IDs or a non-existent ID."
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "child"
          ]
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
            "component": {
              "const": "Tabs"
            },
            "tabs": {
              "type": "array",
              "description": "An array of objects, where each object defines a tab with a title and a child component.",
              "minItems": 1,
              "items": {
                "type": "object",
                "properties": {
                  "title": {
                    "description": "The tab title.",
                    "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"
                  },
                  "child": {
                    "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId",
                    "description": "The ID of the child component."
                  }
                },
                "required": [
                  "title",
                  "child"
                ],
                "additionalProperties": false
              }
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "tabs"
          ]
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
            "component": {
              "const": "Modal"
            },
            "trigger": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId",
              "description": "The ID of the component that opens the modal when interacted with (e.g., a button)."
            },
            "content": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId",
              "description": "The ID of the component to be displayed inside the modal."
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "trigger",
            "content"
          ]
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
            "component": {
              "const": "Divider"
            },
            "axis": {
              "type": "string",
              "description": "The orientation of the divider.",
              "enum": [
                "horizontal",
                "vertical"
              ],
              "default": "horizontal"
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component"
          ]
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
            "component": {
              "const": "Button"
            },
            "child": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId",
              "description": "The ID of the child component. Use a 'Text' component for a labeled button. Only use an 'Icon' if the requirements explicitly ask for an icon-only button."
            },
            "variant": {
              "type": "string",
              "description": "A hint for the button style. If omitted, a default button style is used. 'primary' indicates this is the main call-to-action button. 'borderless' means the button has no visual border or background, making its child content appear like a clickable link.",
              "enum": [
                "default",
                "primary",
                "borderless"
              ],
              "default": "default"
            },
            "action": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/Action"
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "child",
            "action"
          ]
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
            "component": {
              "const": "TextField"
            },
            "label": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString",
              "description": "The text label for the input field."
            },
            "value": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString",
              "description": "The value of the text field."
            },
            "variant": {
              "type": "string",
              "description": "The type of input field to display.",
              "enum": [
                "longText",
                "number",
                "shortText",
                "obscured"
              ],
              "default": "shortText"
            },
            "validationRegexp": {
              "type": "string",
              "description": "A regular expression used for client-side validation of the input."
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "label"
          ]
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
            "component": {
              "const": "CheckBox"
            },
            "label": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString",
              "description": "The text to display next to the checkbox."
            },
            "value": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicBoolean",
              "description": "The current state of the checkbox (true for checked, false for unchecked)."
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "label",
            "value"
          ]
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
            "component": {
              "const": "ChoicePicker"
            },
            "label": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString",
              "description": "The label for the group of options."
            },
            "variant": {
              "type": "string",
              "description": "A hint for how the choice picker should be displayed and behave.",
              "enum": [
                "multipleSelection",
                "mutuallyExclusive"
              ],
              "default": "mutuallyExclusive"
            },
            "options": {
              "type": "array",
              "description": "The list of available options to choose from.",
              "items": {
                "type": "object",
                "properties": {
                  "label": {
                    "description": "The text to display for this option.",
                    "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"
                  },
                  "value": {
                    "type": "string",
                    "description": "The stable value associated with this option."
                  }
                },
                "required": [
                  "label",
                  "value"
                ],
                "additionalProperties": false
              }
            },
            "value": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicStringList",
              "description": "The list of currently selected values. This should be bound to a string array in the data model."
            },
            "displayStyle": {
              "type": "string",
              "description": "The display style of the component.",
              "enum": [
                "checkbox",
                "chips"
              ],
              "default": "checkbox"
            },
            "filterable": {
              "type": "boolean",
              "description": "If true, displays a search input to filter the options.",
              "default": false
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "options",
            "value"
          ]
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
            "component": {
              "const": "Slider"
            },
            "label": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString",
              "description": "The label for the slider."
            },
            "min": {
              "type": "number",
              "description": "The minimum value of the slider.",
              "default": 0
            },
            "max": {
              "type": "number",
              "description": "The maximum value of the slider."
            },
            "value": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicNumber",
              "description": "The current value of the slider."
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "value",
            "max"
          ]
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
            "component": {
              "const": "DateTimeInput"
            },
            "value": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString",
              "description": "The selected date and/or time value in ISO 8601 format. If not yet set, initialize with an empty string."
            },
            "enableDate": {
              "type": "boolean",
              "description": "If true, allows the user to select a date.",
              "default": false
            },
            "enableTime": {
              "type": "boolean",
              "description": "If true, allows the user to select a time.",
              "default": false
            },
            "min": {
              "allOf": [
                {
                  "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"
                },
                {
                  "if": {
                    "type": "string"
                  },
                  "then": {
                    "oneOf": [
                      {
                        "format": "date"
                      },
                      {
                        "format": "time"
                      },
                      {
                        "format": "date-time"
                      }
                    ]
                  }
                }
              ],
              "description": "The minimum allowed date/time in ISO 8601 format."
            },
            "max": {
              "allOf": [
                {
                  "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString"
                },
                {
                  "if": {
                    "type": "string"
                  },
                  "then": {
                    "oneOf": [
                      {
                        "format": "date"
                      },
                      {
                        "format": "time"
                      },
                      {
                        "format": "date-time"
                      }
                    ]
                  }
                }
              ],
              "description": "The maximum allowed date/time in ISO 8601 format."
            },
            "label": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/DynamicString",
              "description": "The text label for the input field."
            },
            "id": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/ComponentId"
            },
            "accessibility": {
              "$ref": "https://a2ui.org/schemas/v0_9_1/common.json#/$defs/AccessibilityAttributes"
            },
            "weight": {
              "type": "number"
            }
          },
          "required": [
            "component",
            "value"
          ]
        }
        """,
      remoteSchemas: remote
    )
    return ComponentAPI(name: "DateTimeInput", schema: schema)
  }()
  // MARK: - All Components
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
