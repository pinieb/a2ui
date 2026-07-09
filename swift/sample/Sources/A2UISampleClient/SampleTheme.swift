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
import OrderedJSON

/// A sample theme for the A2UI demo app.
public struct SampleTheme: SurfaceTheme {
  public let primaryColor: String
  public let iconUrl: String?
  public let agentDisplayName: String

  public init(
    primaryColor: String = "#1A73E8",
    iconUrl: String? = nil,
    agentDisplayName: String = "A2UI Agent"
  ) {
    self.primaryColor = primaryColor
    self.iconUrl = iconUrl
    self.agentDisplayName = agentDisplayName
  }
}
