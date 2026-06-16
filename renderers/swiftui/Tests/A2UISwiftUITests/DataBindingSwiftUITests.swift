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
import A2UISwiftUI
import Foundation
import JSONSchema
import SwiftUI
import Testing

struct DataBindingSwiftUITests {

  // Helper to create a thread-safe state container for testing bindings
  private final class TestState<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T

    init(_ value: T) {
      self._value = value
    }

    var value: T {
      get { lock.withLock { _value } }
      set { lock.withLock { _value = newValue } }
    }
  }

  // MARK: - Tier 1: Feature Coverage

  @Test func `Binding getter propagates value from core model`() {
    let state = TestState("Hello")
    let dataBinding = DataBinding<String>(
      identity: .path("/text"),
      get: { state.value },
      set: { state.value = $0 }
    )

    let swiftUIBinding = dataBinding.swiftUI

    #expect(swiftUIBinding.wrappedValue == "Hello")
  }

  @Test func `Binding setter propagates value back to core model`() {
    let state = TestState("Hello")
    let dataBinding = DataBinding<String>(
      identity: .path("/text"),
      get: { state.value },
      set: { state.value = $0 }
    )

    let swiftUIBinding = dataBinding.swiftUI
    swiftUIBinding.wrappedValue = "World"

    #expect(state.value == "World")
    #expect(swiftUIBinding.wrappedValue == "World")
  }

  @Test func `String binding supports two-way data flow`() {
    let state = TestState("Initial")
    let dataBinding = DataBinding<String>(
      identity: .path("/str"),
      get: { state.value },
      set: { state.value = $0 }
    )

    let binding = dataBinding.swiftUI
    #expect(binding.wrappedValue == "Initial")

    binding.wrappedValue = "Updated"
    #expect(state.value == "Updated")

    state.value = "ModelChange"
    #expect(binding.wrappedValue == "ModelChange")
  }

  @Test func `Boolean binding supports two-way data flow`() {
    let state = TestState(false)
    let dataBinding = DataBinding<Bool>(
      identity: .path("/active"),
      get: { state.value },
      set: { state.value = $0 }
    )

    let binding = dataBinding.swiftUI
    #expect(!binding.wrappedValue)

    binding.wrappedValue = true
    #expect(state.value)

    state.value = false
    #expect(!binding.wrappedValue)
  }

  @Test func `Number binding supports two-way data flow`() {
    let state = TestState(42.0)
    let dataBinding = DataBinding<Double>(
      identity: .path("/score"),
      get: { state.value },
      set: { state.value = $0 }
    )

    let binding = dataBinding.swiftUI
    #expect(binding.wrappedValue == 42.0)

    binding.wrappedValue = 100.5
    #expect(state.value == 100.5)
  }

  @Test func `JSONValue binding supports two-way data flow`() {
    let state = TestState(JSONValue.string("meta"))
    let dataBinding = DataBinding<JSONValue>(
      identity: .path("/meta"),
      get: { state.value },
      set: { state.value = $0 }
    )

    let binding = dataBinding.swiftUI
    #expect(binding.wrappedValue == .string("meta"))

    binding.wrappedValue = .number(123)
    #expect(state.value == .number(123))
  }

  // MARK: - Tier 2: Boundary & Corner Cases

  @Test func `Binding supports optional values`() {
    let state = TestState<String?>(nil)
    let dataBinding = DataBinding<String?>(
      identity: .path("/opt"),
      get: { state.value },
      set: { state.value = $0 }
    )

    let binding = dataBinding.swiftUI
    #expect(binding.wrappedValue == nil)

    binding.wrappedValue = "Present"
    #expect(state.value == "Present")

    binding.wrappedValue = nil
    #expect(state.value == nil)
  }

  @Test func `Concurrent binding writes are thread-safe and do not race`() async {
    let state = TestState(0)
    let dataBinding = DataBinding<Int>(
      identity: .path("/count"),
      get: { state.value },
      set: { state.value = $0 }
    )

    let binding = dataBinding.swiftUI
    let testLock = NSLock()

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<100 {
        group.addTask {
          testLock.withLock {
            binding.wrappedValue += 1
          }
        }
      }
    }

    #expect(state.value == 100)
  }

  @Test func `Rapid reentrant binding sets resolve safely`() {
    let state = TestState(0)

    // A thread-safe container to hold the binding recursively
    final class BindingBox: @unchecked Sendable {
      var binding: DataBinding<Int>?
    }

    let box = BindingBox()

    // Setter that writes back to itself to test reentrancy limits
    box.binding = DataBinding<Int>(
      identity: .path("/reentrant"),
      get: { state.value },
      set: { newValue in
        state.value = newValue
        if newValue < 5 {
          box.binding?.swiftUI.wrappedValue = newValue + 1
        }
      }
    )

    let binding = box.binding!
    binding.swiftUI.wrappedValue = 1
    #expect(state.value == 5)
  }
}
