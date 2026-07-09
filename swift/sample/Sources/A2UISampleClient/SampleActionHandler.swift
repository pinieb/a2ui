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
import Foundation

/// An action handler that logs actions and errors to the console.
public final class SampleActionHandler: ActionHandling, @unchecked Sendable {
  public init() {}

  public func handle(action: ResolvedAction, from surfaceID: String) {
    switch action.identity {
    case .event(let name, let context):
      print("[A2UI] Action received — surface: \(surfaceID), event: \(name)")
      if let context {
        print("[A2UI]   context: \(context)")
      }
    case .function(let call, let args):
      print("[A2UI] Action received — surface: \(surfaceID), function: \(call)")
      if let args {
        print("[A2UI]   args: \(args)")
      }
    }
  }

  public func handle(error: ClientServerError, from surfaceID: String) {
    switch error {
    case .validationFailed(let err):
      print("[A2UI] Validation error — surface: \(surfaceID), path: \(err.path), message: \(err.message)")
    case .generic(let err):
      print("[A2UI] Error — surface: \(surfaceID), code: \(err.code), message: \(err.message)")
    }
  }
}
