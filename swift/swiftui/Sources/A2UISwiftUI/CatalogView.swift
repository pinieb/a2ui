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
import SwiftUI

/// A protocol that all catalog views must conform to, enabling the
/// SwiftUI rendering layer to construct catalog-defined views from
/// resolved engine nodes.
public protocol CatalogView: View {
  /// Initializes the catalog view with a resolved engine node.
  init(node: Node)
}
