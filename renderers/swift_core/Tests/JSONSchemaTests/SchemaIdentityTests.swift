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
import JSONSchema
import Testing

struct SchemaIdentityTests {

  @Test func testRFC6901Escaping() throws {
    // Append a path segment containing a literal / and ~.
    // Assert that the resulting pointer string correctly escapes them to ~1 and ~0.
    let identity = SchemaIdentity(baseURI: "https://example.com/schema")
    let updated = identity.appending(path: "user/name~temp")

    #expect(updated.pointer.stringRepresentation == "#/user~1name~0temp")
    #expect(updated.fullURI == "https://example.com/schema#/user~1name~0temp")

    // Let's also verify round-trip initialization of JSONPointer from string.
    let pointer = JSONPointer(stringRepresentation: "#/user~1name~0temp")
    #expect(pointer.segments == ["user/name~temp"])
  }

  @Test func testAppendingPaths() throws {
    // Start with a base identity, append "properties", then append "age".
    // Assert the full URI correctly reflects #/properties/age.
    let base = SchemaIdentity(baseURI: "https://example.com/schema")
    let step1 = base.appending(path: "properties")
    let step2 = step1.appending(path: "age")

    #expect(step1.pointer.stringRepresentation == "#/properties")
    #expect(step1.fullURI == "https://example.com/schema#/properties")

    #expect(step2.pointer.stringRepresentation == "#/properties/age")
    #expect(step2.fullURI == "https://example.com/schema#/properties/age")
  }

  @Test func testIdBaseReset() throws {
    // Start with an identity http://api.com/v1#/properties/user.
    // Call updatingBaseURI(to: "http://api.com/v2/user").
    // Assert the new full URI is exactly http://api.com/v2/user# (the pointer is wiped clean).
    let initial = SchemaIdentity(uri: "http://api.com/v1#/properties/user")
    #expect(initial.baseURI == "http://api.com/v1")
    #expect(initial.pointer.stringRepresentation == "#/properties/user")

    let updated = initial.updatingBaseURI(to: "http://api.com/v2/user")
    #expect(updated.baseURI == "http://api.com/v2/user")
    #expect(updated.pointer.segments.isEmpty)
    #expect(updated.fullURI == "http://api.com/v2/user#")
  }

  @Test func testEmptySegments() throws {
    // Test "/" parsing to a single empty segment [""] under RFC 6901.
    let pointer1 = JSONPointer(stringRepresentation: "/")
    #expect(pointer1.segments == [""])
    #expect(pointer1.stringRepresentation == "#/")

    let pointer2 = JSONPointer(stringRepresentation: "#/")
    #expect(pointer2.segments == [""])
    #expect(pointer2.stringRepresentation == "#/")

    // Test standard empty pointer
    let pointer3 = JSONPointer(stringRepresentation: "")
    #expect(pointer3.segments.isEmpty)
    #expect(pointer3.stringRepresentation == "#")

    let pointer4 = JSONPointer(stringRepresentation: "#")
    #expect(pointer4.segments.isEmpty)
    #expect(pointer4.stringRepresentation == "#")
  }

  @Test func testPercentEncoding() throws {
    // Test that percent encoding is handled correctly in URI fragments.
    let identity = SchemaIdentity(uri: "https://example.com/schema#/properties/first%20name")
    #expect(identity.pointer.segments == ["properties", "first name"])
    #expect(identity.fullURI == "https://example.com/schema#/properties/first%20name")

    // Test constructing percent-encoded paths.
    let spaceIdentity = SchemaIdentity(baseURI: "https://example.com/schema")
      .appending(path: "properties")
      .appending(path: "first name")
    #expect(spaceIdentity.pointer.stringRepresentation == "#/properties/first%20name")
    #expect(spaceIdentity.fullURI == "https://example.com/schema#/properties/first%20name")
  }
}
