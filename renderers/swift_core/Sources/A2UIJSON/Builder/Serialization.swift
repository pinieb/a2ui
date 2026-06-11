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
import os

public enum SchemaSorting: Sendable {
  /// No sorting guarantees (uses default Swift dictionary hashing order).
  case none

  /// Keys are sorted alphabetically (guarantees a deterministic output).
  case alphabetical
}

public enum SchemaError: Error, Sendable {
  case serializationFailed(String)
}

extension CodingUserInfoKey {
  public static let referenceTracker = CodingUserInfoKey(
    rawValue: "dev.a2ui.referenceTracker"
  )!
}

public final class ReferenceTracker: @unchecked Sendable {
  public let bundleExternalRefs: Bool

  private struct State {
    var registeredStubs: [String: ExternalSchemaStub] = [:]
    var orderedKeys: [String] = []
  }

  private let lock = OSAllocatedUnfairLock(initialState: State())

  public init(bundleExternalRefs: Bool) {
    self.bundleExternalRefs = bundleExternalRefs
  }

  public var registeredStubs: [String: ExternalSchemaStub] {
    lock.withLock { $0.registeredStubs }
  }

  public var orderedKeys: [String] {
    lock.withLock { $0.orderedKeys }
  }

  public func register(_ stub: ExternalSchemaStub) -> String {
    let uri = stub.uri
    let baseKey = lastPathComponentWithoutExtension(from: uri)

    return lock.withLock { state in
      // 1. If already registered with the exact same URI, return existing key
      for (existingKey, existingStub) in state.registeredStubs {
        if existingStub.uri == uri {
          return existingKey
        }
      }

      // 2. Resolve key collision by appending a counter
      var key = baseKey
      var counter = 1
      while state.registeredStubs[key] != nil {
        key = "\(baseKey)\(counter)"
        counter += 1
      }

      state.registeredStubs[key] = stub
      state.orderedKeys.append(key)
      return key
    }
  }

  private func lastPathComponentWithoutExtension(
    from uri: String
  ) -> String {
    let components = uri.split(separator: "/")
    guard let last = components.last else { return "ref" }
    let subcomponents = last.split(separator: ".")
    if subcomponents.count > 1 {
      return String(subcomponents.dropLast().joined(separator: "."))
    }
    return String(last)
  }
}

struct RootWrapper: Encodable {
  let schemaObject: SchemaObject
  let tracker: ReferenceTracker

  enum CodingKeys: String, CodingKey {
    case defs = "$defs"
  }

  func encode(to encoder: Encoder) throws {
    try schemaObject.encode(to: encoder)

    if tracker.bundleExternalRefs {
      var container = encoder.container(keyedBy: CodingKeys.self)
      var defsContainer = container.nestedContainer(
        keyedBy: DynamicCodingKeys.self,
        forKey: .defs
      )

      var processedKeys = Set<String>()
      while true {
        let currentKeys = tracker.orderedKeys
        let unprocessed = currentKeys.filter { !processedKeys.contains($0) }
        if unprocessed.isEmpty { break }

        for key in unprocessed {
          if let stub = tracker.registeredStubs[key] {
            try defsContainer.encode(
              stub,
              forKey: DynamicCodingKeys(stringValue: key)
            )
          }
          processedKeys.insert(key)
        }
      }
    }
  }
}

extension SchemaObject {
  public func print(
    bundleExternalRefs: Bool,
    sorting: SchemaSorting = .none,
    escapingSlashes: Bool = false,
    prettyPrinted: Bool = false
  ) throws -> String {
    let encoder = JSONEncoder()

    var formatting: JSONEncoder.OutputFormatting = []
    if prettyPrinted {
      formatting.insert(.prettyPrinted)
    }
    if sorting == .alphabetical {
      formatting.insert(.sortedKeys)
    }
    if !escapingSlashes {
      formatting.insert(.withoutEscapingSlashes)
    }
    encoder.outputFormatting = formatting

    let tracker = ReferenceTracker(bundleExternalRefs: bundleExternalRefs)
    encoder.userInfo[.referenceTracker] = tracker

    let wrapper = RootWrapper(schemaObject: self, tracker: tracker)
    let data = try encoder.encode(wrapper)
    guard let string = String(data: data, encoding: .utf8) else {
      throw SchemaError.serializationFailed(
        "Failed to convert encoded data to UTF-8 string"
      )
    }
    return string
  }
}
