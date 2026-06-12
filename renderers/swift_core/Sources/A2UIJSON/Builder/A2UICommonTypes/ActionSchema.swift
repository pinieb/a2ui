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

import Foundation

extension A2UICommonSchema {
  public static let action: JSONSchema = JSONSchema.anyOf {
    JSONSchema.object {
      JSONSchemaProperty.property("event", isRequired: true) {
        JSONSchema.object {
          JSONSchemaProperty.property("name", isRequired: true) { JSONSchema.string() }
          JSONSchemaProperty.property("context") {
            JSONSchema.object(
              additionalProperties: JSONSchema.reference(A2UICommonSchema.dynamicValue)
            )
          }
        }
      }
    }
    JSONSchema.object {
      JSONSchemaProperty.property("functionCall", isRequired: true) {
        JSONSchema.reference(A2UICommonSchema.functionCall)
      }
    }
  }
}




// Note: We intentionally don't wrap this schema in a stub(uri:...) to preserve the historical flat array/object shape representation.
