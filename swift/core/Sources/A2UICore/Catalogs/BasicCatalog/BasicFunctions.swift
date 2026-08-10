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
import OrderedCollections
import OrderedJSON

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

// MARK: - Required Function

public struct RequiredFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "required",
    returnType: .boolean,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "value": {}
          },
          "required": ["value"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    guard let value = arguments["value"] else { return .boolean(false) }
    switch value {
    case .null:
      return .boolean(false)
    case .string(let str):
      return .boolean(!str.isEmpty)
    case .array(let arr):
      return .boolean(!arr.isEmpty)
    case .object(let dict):
      return .boolean(!dict.isEmpty)
    default:
      return .boolean(true)
    }
  }
}

// MARK: - Regex Function

public struct RegexFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "regex",
    returnType: .boolean,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "value": { "type": "string" },
            "pattern": { "type": "string" }
          },
          "required": ["value", "pattern"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    guard let value = arguments["value"]?.stringValue,
      let pattern = arguments["pattern"]?.stringValue
    else {
      return .boolean(false)
    }
    do {
      let regex = try NSRegularExpression(pattern: pattern)
      let range = NSRange(value.startIndex..<value.endIndex, in: value)
      let matches = regex.firstMatch(in: value, options: [], range: range)
      return .boolean(matches != nil)
    } catch {
      return .boolean(false)
    }
  }
}

// MARK: - Length Function

public struct LengthFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "length",
    returnType: .boolean,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "value": { "type": "string" },
            "min": { "type": "integer", "minimum": 0 },
            "max": { "type": "integer", "minimum": 0 }
          },
          "required": ["value"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    let count: Int
    if let str = arguments["value"]?.stringValue {
      count = str.count
    } else if let arr = arguments["value"]?.arrayValue {
      count = arr.count
    } else {
      return .boolean(false)
    }

    if let min = arguments["min"]?.intValue, count < min {
      return .boolean(false)
    }
    if let max = arguments["max"]?.intValue, count > max {
      return .boolean(false)
    }
    return .boolean(true)
  }
}

// MARK: - Numeric Function

public struct NumericFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "numeric",
    returnType: .boolean,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "value": { "type": "number" },
            "min": { "type": "number" },
            "max": { "type": "number" }
          },
          "required": ["value"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    let numVal: Double
    if let num = arguments["value"]?.doubleValue {
      numVal = num
    } else if let str = arguments["value"]?.stringValue, let parsed = Double(str) {
      numVal = parsed
    } else {
      return .boolean(false)
    }

    if let min = arguments["min"]?.doubleValue, numVal < min {
      return .boolean(false)
    }
    if let max = arguments["max"]?.doubleValue, numVal > max {
      return .boolean(false)
    }
    return .boolean(true)
  }
}

// MARK: - Email Function

public struct EmailFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "email",
    returnType: .boolean,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "value": { "type": "string" }
          },
          "required": ["value"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    guard let value = arguments["value"]?.stringValue else { return .boolean(false) }
    let pattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return .boolean(false) }
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return .boolean(regex.firstMatch(in: value, options: [], range: range) != nil)
  }
}

// MARK: - FormatString Function

public struct FormatStringFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "formatString",
    returnType: .string,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "value": { "type": "string" }
          },
          "required": ["value"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    guard let template = arguments["value"]?.stringValue else {
      return .string("")
    }

    let parser = ExpressionParser()
    let parts: [JSONValue]
    do {
      parts = try parser.parse(template)
    } catch {
      return .string(template)
    }

    if parts.isEmpty {
      return .string("")
    }

    let dataContext = arguments["__data__"]
    let basePath = arguments["__basePath__"]?.stringValue
    let availableFunctions = BasicFunctions.standardFunctionsMap

    var result = ""
    for part in parts {
      result.append(
        evaluatePart(
          part,
          data: dataContext,
          basePath: basePath,
          arguments: arguments,
          functions: availableFunctions
        )
      )
    }

    return .string(result)
  }

  private func evaluatePart(
    _ part: JSONValue,
    data: JSONValue?,
    basePath: String?,
    arguments: [String: JSONValue],
    functions: [String: any FunctionImplementation]
  ) -> String {
    switch part {
    case .string(let s):
      return s
    case .integer(let i):
      return String(i)
    case .number(let n):
      return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
    case .boolean(let b):
      return String(b)
    case .null:
      return ""
    case .object(let dict):
      if let pathStr = dict["path"]?.stringValue {
        return resolvePath(
          pathStr,
          data: data,
          basePath: basePath,
          arguments: arguments
        )
      } else if let callName = dict["call"]?.stringValue {
        return evaluateCall(
          callName: callName,
          argsObj: dict["args"]?.dictionaryValue,
          data: data,
          basePath: basePath,
          arguments: arguments,
          functions: functions
        )
      }
      return coerceToString(part)
    case .array:
      return coerceToString(part)
    }
  }

  private func resolvePath(
    _ pathStr: String,
    data: JSONValue?,
    basePath: String?,
    arguments: [String: JSONValue]
  ) -> String {
    var cleanPath = pathStr
    while cleanPath.hasPrefix("\\") {
      cleanPath = String(cleanPath.dropFirst())
    }
    cleanPath = cleanPath.replacingOccurrences(of: "\\/", with: "/")

    if let argVal = arguments[cleanPath] ?? arguments[pathStr] {
      return coerceToString(argVal)
    }
    if let data {
      let absPath = JSONValue.absolutePath(for: cleanPath, in: basePath)
      if let dataVal = data[absPath] ?? data[cleanPath] ?? data[pathStr] {
        return coerceToString(dataVal)
      }
    }
    return ""
  }

  private func evaluateCall(
    callName: String,
    argsObj: [String: JSONValue]?,
    data: JSONValue?,
    basePath: String?,
    arguments: [String: JSONValue],
    functions: [String: any FunctionImplementation]
  ) -> String {
    guard let function = functions[callName] else {
      return ""
    }
    var resolvedArgs: [String: JSONValue] = [:]
    if let argsObj {
      for (argKey, argVal) in argsObj {
        resolvedArgs[argKey] = evaluateArgValue(
          argVal,
          data: data,
          basePath: basePath,
          arguments: arguments,
          functions: functions
        )
      }
    }
    if let data {
      resolvedArgs["__data__"] = data
    }
    if let basePath {
      resolvedArgs["__basePath__"] = .string(basePath)
    }
    if let result = try? function.evaluate(arguments: resolvedArgs) {
      return coerceToString(result)
    }
    return ""
  }

  private func evaluateArgValue(
    _ argVal: JSONValue,
    data: JSONValue?,
    basePath: String?,
    arguments: [String: JSONValue],
    functions: [String: any FunctionImplementation]
  ) -> JSONValue {
    switch argVal {
    case .object(let dict):
      if let pathStr = dict["path"]?.stringValue {
        var cleanPath = pathStr
        while cleanPath.hasPrefix("\\") {
          cleanPath = String(cleanPath.dropFirst())
        }
        cleanPath = cleanPath.replacingOccurrences(of: "\\/", with: "/")

        if let val = arguments[cleanPath] ?? arguments[pathStr] {
          return val
        }
        if let data {
          let absPath = JSONValue.absolutePath(for: cleanPath, in: basePath)
          if let val = data[absPath] ?? data[cleanPath] ?? data[pathStr] {
            return val
          }
        }
        return .null
      } else if let callName = dict["call"]?.stringValue {
        let str = evaluateCall(
          callName: callName,
          argsObj: dict["args"]?.dictionaryValue,
          data: data,
          basePath: basePath,
          arguments: arguments,
          functions: functions
        )
        return .string(str)
      }
      return argVal
    default:
      return argVal
    }
  }

  private func coerceToString(_ value: JSONValue) -> String {
    switch value {
    case .string(let s): return s
    case .number(let n):
      return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
    case .integer(let i): return String(i)
    case .boolean(let b): return String(b)
    case .null: return ""
    default: return "\(value)"
    }
  }
}

// MARK: - FormatNumber Function

public struct FormatNumberFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "formatNumber",
    returnType: .string,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "value": { "type": "number" },
            "decimals": { "type": "number" },
            "grouping": { "type": "boolean" }
          },
          "required": ["value"]
        }
        """
    )
  )

  private let locale: Locale

  public init(locale: Locale = .current) {
    self.locale = locale
  }

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    guard let number = arguments["value"]?.doubleValue else {
      return .string("")
    }

    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal

    if let decimals = arguments["decimals"]?.intValue {
      formatter.minimumFractionDigits = decimals
      formatter.maximumFractionDigits = decimals
    }
    if let grouping = arguments["grouping"]?.boolValue {
      formatter.usesGroupingSeparator = grouping
    } else {
      formatter.usesGroupingSeparator = true
    }

    let formatted = formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    return .string(formatted)
  }
}

// MARK: - FormatCurrency Function

public struct FormatCurrencyFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "formatCurrency",
    returnType: .string,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "value": { "type": "number" },
            "currency": { "type": "string" },
            "decimals": { "type": "number" },
            "grouping": { "type": "boolean" }
          },
          "required": ["value", "currency"]
        }
        """
    )
  )

  private let locale: Locale

  public init(locale: Locale = .current) {
    self.locale = locale
  }

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    guard let number = arguments["value"]?.doubleValue,
      let currency = arguments["currency"]?.stringValue
    else {
      return .string("")
    }

    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .currency
    formatter.currencyCode = currency

    if let decimals = arguments["decimals"]?.intValue {
      formatter.minimumFractionDigits = decimals
      formatter.maximumFractionDigits = decimals
    } else {
      formatter.minimumFractionDigits = 2
      formatter.maximumFractionDigits = 2
    }
    if let grouping = arguments["grouping"]?.boolValue {
      formatter.usesGroupingSeparator = grouping
    } else {
      formatter.usesGroupingSeparator = true
    }

    let formatted = formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    return .string(formatted)
  }
}

// MARK: - FormatDate Function

public struct FormatDateFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "formatDate",
    returnType: .string,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "value": {},
            "format": { "type": "string" }
          },
          "required": ["value", "format"]
        }
        """
    )
  )

  private let locale: Locale

  public init(locale: Locale = .current) {
    self.locale = locale
  }

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    guard let val = arguments["value"],
      let format = arguments["format"]?.stringValue
    else {
      return .string("")
    }

    let date: Date?
    switch val {
    case .string(let dateStr):
      let isoFull = ISO8601DateFormatter()
      isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      let isoStandard = ISO8601DateFormatter()
      let isoDateOnly = ISO8601DateFormatter()
      isoDateOnly.formatOptions = [.withFullDate]

      let dateOnlyFormatter = DateFormatter()
      dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
      dateOnlyFormatter.dateFormat = "yyyy-MM-dd"

      date =
        isoFull.date(from: dateStr)
        ?? isoStandard.date(from: dateStr)
        ?? isoDateOnly.date(from: dateStr)
        ?? dateOnlyFormatter.date(from: dateStr)
    case .number(let timestamp):
      date =
        timestamp > 10_000_000_000
        ? Date(timeIntervalSince1970: timestamp / 1000.0) : Date(timeIntervalSince1970: timestamp)
    case .integer(let timestamp):
      let t = Double(timestamp)
      date =
        t > 10_000_000_000
        ? Date(timeIntervalSince1970: t / 1000.0) : Date(timeIntervalSince1970: t)
    default:
      date = nil
    }

    guard let validDate = date else {
      return .string("")
    }

    if format == "ISO" {
      return .string(ISO8601DateFormatter().string(from: validDate))
    }

    let formatter = DateFormatter()
    formatter.locale = locale
    if let dateStr = val.stringValue, !dateStr.contains("T") && !dateStr.contains(":") {
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
    }
    formatter.dateFormat = format
    return .string(formatter.string(from: validDate))
  }
}

// MARK: - Pluralize Function

public struct PluralizeFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "pluralize",
    returnType: .string,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "value": { "type": "number" },
            "zero": { "type": "string" },
            "one": { "type": "string" },
            "two": { "type": "string" },
            "few": { "type": "string" },
            "many": { "type": "string" },
            "other": { "type": "string" }
          },
          "required": ["value", "other"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    guard let count = arguments["value"]?.doubleValue else {
      return .string(arguments["other"]?.stringValue ?? "")
    }

    if count == 0, let zero = arguments["zero"]?.stringValue {
      return .string(zero)
    }
    if count == 1, let one = arguments["one"]?.stringValue {
      return .string(one)
    }
    if count == 2, let two = arguments["two"]?.stringValue {
      return .string(two)
    }
    if let few = arguments["few"]?.stringValue, count >= 3 && count <= 5 {
      return .string(few)
    }
    if let many = arguments["many"]?.stringValue, count > 5 {
      return .string(many)
    }
    return .string(arguments["other"]?.stringValue ?? "")
  }
}

// MARK: - OpenUrl Function

public struct OpenUrlFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "openUrl",
    returnType: .void,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "url": { "type": "string" }
          },
          "required": ["url"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    guard let urlStr = arguments["url"]?.stringValue,
      let url = URL(string: urlStr),
      url.scheme == "http" || url.scheme == "https"
    else {
      return .null
    }

    #if canImport(UIKit)
      DispatchQueue.main.async {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
    #elseif canImport(AppKit)
      DispatchQueue.main.async {
        NSWorkspace.shared.open(url)
      }
    #endif

    return .null
  }
}

// MARK: - Logical Functions

public struct AndFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "and",
    returnType: .boolean,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "values": { "type": "array", "items": { "type": "boolean" }, "minItems": 2 }
          },
          "required": ["values"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    guard let values = arguments["values"]?.arrayValue else { return .boolean(false) }
    for v in values {
      if v.boolValue != true {
        return .boolean(false)
      }
    }
    return .boolean(true)
  }
}

public struct OrFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "or",
    returnType: .boolean,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "values": { "type": "array", "items": { "type": "boolean" }, "minItems": 2 }
          },
          "required": ["values"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    guard let values = arguments["values"]?.arrayValue else { return .boolean(false) }
    for v in values {
      if v.boolValue == true {
        return .boolean(true)
      }
    }
    return .boolean(false)
  }
}

public struct NotFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "not",
    returnType: .boolean,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "value": { "type": "boolean" }
          },
          "required": ["value"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    let val = arguments["value"]?.boolValue ?? false
    return .boolean(!val)
  }
}

// MARK: - Arithmetic & Comparison Functions

public struct AddFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "add",
    returnType: .number,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "a": { "type": "number" },
            "b": { "type": "number" }
          },
          "required": ["a", "b"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    let a = arguments["a"]?.doubleValue ?? 0
    let b = arguments["b"]?.doubleValue ?? 0
    return .number(a + b)
  }
}

public struct SubtractFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "subtract",
    returnType: .number,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "a": { "type": "number" },
            "b": { "type": "number" }
          },
          "required": ["a", "b"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    let a = arguments["a"]?.doubleValue ?? 0
    let b = arguments["b"]?.doubleValue ?? 0
    return .number(a - b)
  }
}

public struct MultiplyFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "multiply",
    returnType: .number,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "a": { "type": "number" },
            "b": { "type": "number" }
          },
          "required": ["a", "b"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    let a = arguments["a"]?.doubleValue ?? 0
    let b = arguments["b"]?.doubleValue ?? 0
    return .number(a * b)
  }
}

public struct DivideFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "divide",
    returnType: .number,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "a": { "type": "number" },
            "b": { "type": "number" }
          },
          "required": ["a", "b"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    let a = arguments["a"]?.doubleValue ?? 0
    let b = arguments["b"]?.doubleValue ?? 1
    guard b != 0 else { return .null }
    return .number(a / b)
  }
}

public struct EqualsFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "equals",
    returnType: .boolean,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "a": {},
            "b": {}
          },
          "required": ["a", "b"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    let a = arguments["a"]
    let b = arguments["b"]
    return .boolean(a == b)
  }
}

public struct NotEqualsFunction: FunctionImplementation, Sendable {
  public let api = FunctionAPI(
    name: "notEquals",
    returnType: .boolean,
    schema: try! Schema(
      instance: """
        {
          "type": "object",
          "properties": {
            "a": {},
            "b": {}
          },
          "required": ["a", "b"]
        }
        """
    )
  )

  public init() {}

  public func evaluate(arguments: [String: JSONValue]) throws -> JSONValue {
    let a = arguments["a"]
    let b = arguments["b"]
    return .boolean(a != b)
  }
}

// MARK: - Basic Functions Collection

public enum BasicFunctions: Sendable {
  public static var allFunctions: [any FunctionImplementation] {
    [
      RequiredFunction(),
      RegexFunction(),
      LengthFunction(),
      NumericFunction(),
      EmailFunction(),
      FormatStringFunction(),
      FormatNumberFunction(),
      FormatCurrencyFunction(),
      FormatDateFunction(),
      PluralizeFunction(),
      OpenUrlFunction(),
      AndFunction(),
      OrFunction(),
      NotFunction(),
      AddFunction(),
      SubtractFunction(),
      MultiplyFunction(),
      DivideFunction(),
      EqualsFunction(),
      NotEqualsFunction(),
    ]
  }

  public static var standardFunctionsMap: [String: any FunctionImplementation] {
    var dict: [String: any FunctionImplementation] = [:]
    for fn in allFunctions {
      dict[fn.api.name] = fn
    }
    return dict
  }
}
