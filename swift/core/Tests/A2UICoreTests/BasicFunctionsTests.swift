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
import OrderedJSON
import Testing

// MARK: - Basic Functions Tests

struct BasicFunctionsTests {

  @Test func requiredFunctionEvaluatesCorrectly() throws {
    let fn = RequiredFunction()
    #expect(try fn.evaluate(arguments: ["value": .string("hello")]).boolValue == true)
    #expect(try fn.evaluate(arguments: ["value": .string("")]).boolValue == false)
    #expect(try fn.evaluate(arguments: ["value": .null]).boolValue == false)
    #expect(try fn.evaluate(arguments: [:]).boolValue == false)
    #expect(try fn.evaluate(arguments: ["value": .array([.string("a")])]).boolValue == true)
    #expect(try fn.evaluate(arguments: ["value": .array([])]).boolValue == false)
  }

  @Test func regexFunctionEvaluatesCorrectly() throws {
    let fn = RegexFunction()
    #expect(
      try fn.evaluate(arguments: ["value": .string("12345"), "pattern": .string("^[0-9]+$")])
        .boolValue == true)
    #expect(
      try fn.evaluate(arguments: ["value": .string("abc"), "pattern": .string("^[0-9]+$")])
        .boolValue == false)
  }

  @Test func lengthFunctionEvaluatesCorrectly() throws {
    let fn = LengthFunction()
    #expect(
      try fn.evaluate(arguments: [
        "value": .string("hello"), "min": .integer(2), "max": .integer(10),
      ]).boolValue == true)
    #expect(
      try fn.evaluate(arguments: ["value": .string("h"), "min": .integer(2)]).boolValue == false)
    #expect(
      try fn.evaluate(arguments: ["value": .string("hello world"), "max": .integer(5)]).boolValue
        == false)
  }

  @Test func numericFunctionEvaluatesCorrectly() throws {
    let fn = NumericFunction()
    #expect(
      try fn.evaluate(arguments: ["value": .number(25), "min": .number(10), "max": .number(50)])
        .boolValue == true)
    #expect(
      try fn.evaluate(arguments: ["value": .number(5), "min": .number(10)]).boolValue == false)
    #expect(
      try fn.evaluate(arguments: ["value": .number(100), "max": .number(50)]).boolValue == false)
  }

  @Test func emailFunctionEvaluatesCorrectly() throws {
    let fn = EmailFunction()
    #expect(try fn.evaluate(arguments: ["value": .string("test@example.com")]).boolValue == true)
    #expect(try fn.evaluate(arguments: ["value": .string("invalid-email")]).boolValue == false)
  }

  @Test func formatStringFunctionEvaluatesCorrectly() throws {
    let fn = FormatStringFunction()
    let res = try fn.evaluate(arguments: [
      "value": .string("Hello ${name}! You have ${count} messages."),
      "name": .string("Alice"),
      "count": .integer(5),
    ])
    #expect(res.stringValue == "Hello Alice! You have 5 messages.")

    let pathRes = try fn.evaluate(arguments: [
      "value": .string("You typed: ${/inputValue}"),
      "__data__": .object(["inputValue": .string("Hello!")]),
    ])
    #expect(pathRes.stringValue == "You typed: Hello!")

    let template =
      "${formatDate(value: ${/start}, format: 'E, MMM d')} • "
      + "${formatDate(value: ${/start}, format: 'h:mm a')} - "
      + "${formatDate(value: ${/end}, format: 'h:mm a')}"
    let nestedDateRes = try fn.evaluate(arguments: [
      "value": .string(template),
      "__data__": .object([
        "start": .string("2025-12-19T14:00:00Z"),
        "end": .string("2025-12-19T15:30:00Z"),
      ]),
    ])
    #expect(nestedDateRes.stringValue?.contains("Fri, Dec 19") == true)
    #expect(nestedDateRes.stringValue?.contains(" • ") == true)
    #expect(nestedDateRes.stringValue?.contains(" - ") == true)

    let nestedCurrencyRes = try fn.evaluate(arguments: [
      "value": .string("${formatCurrency(value: ${/total}, currency: 'USD')}/year"),
      "__data__": .object(["total": .number(99.5)]),
    ])
    #expect(nestedCurrencyRes.stringValue?.contains("99.50/year") == true)
  }

  @Test func formatNumberFunctionEvaluatesCorrectly() throws {
    let fn = FormatNumberFunction()
    let res = try fn.evaluate(arguments: [
      "value": .number(1234.5678),
      "decimals": .integer(2),
      "grouping": .boolean(true),
    ])
    #expect(
      res.stringValue?.contains("1,234.57") == true || res.stringValue?.contains("1234.57") == true)
  }

  @Test func formatCurrencyFunctionEvaluatesCorrectly() throws {
    let fn = FormatCurrencyFunction()
    let res = try fn.evaluate(arguments: [
      "value": .number(49.99),
      "currency": .string("USD"),
    ])
    #expect(res.stringValue?.contains("49.99") == true)
  }

  @Test func formatDateFunctionEvaluatesCorrectly() throws {
    let fn = FormatDateFunction(locale: Locale(identifier: "en_US"))
    let dateRes = try fn.evaluate(arguments: [
      "value": .string("2025-12-15"),
      "format": .string("E, MMM d"),
    ])
    #expect(dateRes.stringValue == "Mon, Dec 15")

    let timeRes = try fn.evaluate(arguments: [
      "value": .string("2025-12-15T10:15:00Z"),
      "format": .string("h:mm a"),
    ])
    #expect(!timeRes.stringValue!.isEmpty)
  }

  @Test func pluralizeFunctionEvaluatesCorrectly() throws {
    let fn = PluralizeFunction()
    let oneRes = try fn.evaluate(arguments: [
      "value": .number(1), "one": .string("item"), "other": .string("items"),
    ])
    #expect(oneRes.stringValue == "item")

    let otherRes = try fn.evaluate(arguments: [
      "value": .number(5), "one": .string("item"), "other": .string("items"),
    ])
    #expect(otherRes.stringValue == "items")
  }

  @Test func logicalFunctionsEvaluateCorrectly() throws {
    let andFn = AndFunction()
    #expect(
      try andFn.evaluate(arguments: ["values": .array([.boolean(true), .boolean(true)])]).boolValue
        == true)
    #expect(
      try andFn.evaluate(arguments: ["values": .array([.boolean(true), .boolean(false)])]).boolValue
        == false)

    let orFn = OrFunction()
    #expect(
      try orFn.evaluate(arguments: ["values": .array([.boolean(false), .boolean(true)])]).boolValue
        == true)
    #expect(
      try orFn.evaluate(arguments: ["values": .array([.boolean(false), .boolean(false)])]).boolValue
        == false)

    let notFn = NotFunction()
    #expect(try notFn.evaluate(arguments: ["value": .boolean(true)]).boolValue == false)
    #expect(try notFn.evaluate(arguments: ["value": .boolean(false)]).boolValue == true)
  }

  @Test func arithmeticFunctionsEvaluateCorrectly() throws {
    let addFn = AddFunction()
    #expect(try addFn.evaluate(arguments: ["a": .number(10), "b": .number(5)]).doubleValue == 15)

    let subFn = SubtractFunction()
    #expect(try subFn.evaluate(arguments: ["a": .number(10), "b": .number(5)]).doubleValue == 5)

    let mulFn = MultiplyFunction()
    #expect(try mulFn.evaluate(arguments: ["a": .number(10), "b": .number(5)]).doubleValue == 50)

    let divFn = DivideFunction()
    #expect(try divFn.evaluate(arguments: ["a": .number(10), "b": .number(2)]).doubleValue == 5)
  }
}
