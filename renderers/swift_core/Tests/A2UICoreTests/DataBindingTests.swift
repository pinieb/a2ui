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
import Testing

// MARK: - Test Suite

struct DataBindingTests {

  @Test func `read-only literal binding returns literal and ignores set`() {
    let binding = DataBinding<String>(
      identity: .literal(.string("constant")),
      get: { "constant" },
      set: { _ in }
    )

    #expect(binding.get() == "constant")
    binding.set("new")
    #expect(binding.get() == "constant")
  }

  @Test func `mutable binding performs get and set round-trip`() {
    let box = TestStateBox("initial")
    let binding = DataBinding<String>(
      identity: .path("profile.name"),
      get: { box.value },
      set: { box.value = $0 }
    )

    #expect(binding.get() == "initial")
    binding.set("updated")
    #expect(binding.get() == "updated")
    #expect(box.value == "updated")
  }

  @Test func `concurrent reads and writes on DataBinding do not race`() async {
    let box = TestStateBox(0)
    let binding = DataBinding<Int>(
      identity: .path("counter"),
      get: { box.value },
      set: { box.value = $0 }
    )

    await withTaskGroup(of: Void.self) { group in
      for i in 0..<100 {
        group.addTask {
          if i % 2 == 0 {
            _ = binding.get()
          } else {
            binding.set(i)
          }
        }
      }
    }
  }
}
