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
import A2UIJSON

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

nonisolated(unsafe) let swiftStdout = fdopen(1, "w")!
nonisolated(unsafe) let swiftStderr = fdopen(2, "w")!

// MARK: - JSONValue Encodable Conformance
extension JSONValue: @retroactive Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null:
      try container.encodeNil()
    case .boolean(let val):
      try container.encode(val)
    case .number(let val):
      try container.encode(val)
    case .string(let val):
      try container.encode(val)
    case .array(let val):
      try container.encode(val)
    case .object(let val):
      try container.encode(val)
    }
  }
}

// MARK: - Bowtie Protocol Models
struct BowtieRequest: Decodable {
  let cmd: String
  let version: Int?
  let dialect: String?
  let seq: Int?
  let `case`: BowtieTestCase?
}

struct BowtieTestCase: Decodable {
  let description: String
  let schema: JSONValue
  let tests: [BowtieTest]
}

struct BowtieTest: Decodable {
  let description: String
  let instance: JSONValue
}

struct StartResponse: Encodable {
  let version: Int
  let implementation: ImplementationInfo
}

struct ImplementationInfo: Encodable {
  let language: String
  let name: String
  let homepage: String
  let issues: String
  let source: String
  let dialects: [String]
}

struct DialectResponse: Encodable {
  let ok: Bool
}

struct RunSuccessResponse: Encodable {
  let seq: Int
  let results: [TestResult]
}

struct TestResult: Encodable {
  let valid: Bool
}

struct RunErroredResponse: Encodable {
  let seq: Int
  let errored: Bool
  let context: ErrorContext
}

struct ErrorContext: Encodable {
  let message: String
}

// MARK: - Main Entry Point
@main
struct BowtieHarness {
  static func main() {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    
    // Read line by line from stdin
    while let line = readLine() {
      guard let data = line.data(using: .utf8) else { continue }
      
      do {
        let request = try decoder.decode(BowtieRequest.self, from: data)
        switch request.cmd {
        case "start":
          guard let version = request.version, version == 1 else {
            exit(1)
          }
          let response = StartResponse(
            version: 1,
            implementation: ImplementationInfo(
              language: "swift",
              name: "A2UIJSON",
              homepage: "https://github.com/pinieb/a2ui",
              issues: "https://github.com/pinieb/a2ui/issues",
              source: "https://github.com/pinieb/a2ui",
              dialects: ["https://json-schema.org/draft/2020-12/schema"]
            )
          )
          sendResponse(response, encoder: encoder)
          
        case "dialect":
          let isSupported = request.dialect == "https://json-schema.org/draft/2020-12/schema"
          let response = DialectResponse(ok: isSupported)
          sendResponse(response, encoder: encoder)
          
        case "run":
          guard let seq = request.seq, let testCase = request.case else { continue }
          handleRun(seq: seq, testCase: testCase, encoder: encoder)
          
        case "stop":
          exit(0)
          
        default:
          break
        }
      } catch {
        fputs("Failed to decode command: \(error)\n", swiftStderr)
        fflush(swiftStderr)
      }
    }
  }
  
  static func handleRun(seq: Int, testCase: BowtieTestCase, encoder: JSONEncoder) {
    // 1. Serialize the schema JSONValue to a string
    guard let schemaData = try? encoder.encode(testCase.schema),
          let schemaString = String(data: schemaData, encoding: .utf8) else {
      let response = RunErroredResponse(
        seq: seq,
        errored: true,
        context: ErrorContext(message: "Failed to serialize schema")
      )
      sendResponse(response, encoder: encoder)
      return
    }
    
    // 2. Parse the schema string
    let schema: SchemaType
    do {
      schema = try JSONSchema.parse(schemaString)
    } catch {
      let response = RunErroredResponse(
        seq: seq,
        errored: true,
        context: ErrorContext(message: "Schema parsing failed: \(error)")
      )
      sendResponse(response, encoder: encoder)
      return
    }
    
    // 3. Validate each instance
    var results: [TestResult] = []
    for test in testCase.tests {
      do {
        _ = try schema.validate(instance: test.instance)
        results.append(TestResult(valid: true))
      } catch _ as ValidationError {
        results.append(TestResult(valid: false))
      } catch {
        let response = RunErroredResponse(
          seq: seq,
          errored: true,
          context: ErrorContext(message: "Unexpected validation error: \(error)")
        )
        sendResponse(response, encoder: encoder)
        return
      }
    }
    
    // 4. Send success response
    let response = RunSuccessResponse(seq: seq, results: results)
    sendResponse(response, encoder: encoder)
  }
  
  static func sendResponse<T: Encodable>(_ response: T, encoder: JSONEncoder) {
    if let data = try? encoder.encode(response),
       var responseString = String(data: data, encoding: .utf8) {
      responseString.append("\n")
      fputs(responseString, swiftStdout)
      fflush(swiftStdout)
    }
  }
}
