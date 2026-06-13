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

struct ResolvedActionTests {

  @Test func `callAsFunction triggers action`() {
    let triggered = TestStateBox(false)
    let action = ResolvedAction(
      identity: .event(name: "tap", context: nil),
      trigger: {
        triggered.mutate { $0 = true }
      }
    )

    action()

    #expect(triggered.value)
  }

  @Test func `noop action can be invoked without side effects`() {
    let action = ResolvedAction(
      identity: .event(name: "noop", context: nil),
      trigger: {}
    )

    // Verify it does not crash or hang
    action()
  }

  @Test func `concurrent callAsFunction on ResolvedAction do not race`() async {
    let counter = TestStateBox(0)
    let action = ResolvedAction(
      identity: .event(name: "tap", context: nil),
      trigger: {
        counter.mutate { $0 += 1 }
      }
    )

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<100 {
        group.addTask {
          action()
        }
      }
    }

    #expect(counter.value == 100)
  }

  @Test func `concurrent triggers on ResolvedAction do not race`() async {
    let counter = TestStateBox(0)
    let action = ResolvedAction(
      identity: .event(name: "tap", context: nil),
      trigger: {
        counter.mutate { $0 += 1 }
      }
    )

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<100 {
        group.addTask {
          action()
        }
      }
    }

    #expect(counter.value == 100)
  }
}
