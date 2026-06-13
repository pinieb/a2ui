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

public struct Punycode {
  /// Encodes a string of Unicode scalars into Punycode (RFC 3492).
  public static func encode(_ input: String) -> String? {
    let unicode = Array(input.unicodeScalars)

    // Copy all basic code points (ASCII) to the output
    var output = unicode.filter { $0.value < 128 }.map { Character($0) }
    let basicCount = output.count

    if basicCount == unicode.count {
      return input  // No non-ASCII characters
    }

    output.append("-")

    var n = 128
    var delta = 0
    var bias = 72

    var h = basicCount
    while h < unicode.count {
      // Find the next smallest non-basic code point >= n
      guard let m = unicode.map({ Int($0.value) }).filter({ $0 >= n }).min() else {
        break
      }

      delta += (m - n) * (h + 1)
      n = m

      for c in unicode {
        let cVal = Int(c.value)
        if cVal < n {
          delta += 1
        }
        if cVal == n {
          var q = delta
          var k = 36
          while true {
            let t = k <= bias ? 1 : (k >= bias + 26 ? 26 : k - bias)
            if q < t { break }
            let codePoint = t + ((q - t) % (36 - t))
            output.append(encodeDigit(codePoint))
            q = (q - t) / (36 - t)
            k += 36
          }
          output.append(encodeDigit(q))
          bias = adapt(delta, h + 1, h == basicCount)
          delta = 0
          h += 1
        }
      }
      delta += 1
      n += 1
    }

    return String(output)
  }

  /// Converts an internationalized domain name (IDN) to its ASCII Compatible Encoding (ACE)
  /// representation.
  public static func toASCII(_ domain: String) -> String {
    let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
    let asciiLabels = labels.map { label -> String in
      let labelStr = String(label)
      let isASCII = labelStr.unicodeScalars.allSatisfy { $0.value < 128 }
      if isASCII {
        return labelStr
      } else {
        if let encoded = encode(labelStr) {
          return "xn--" + encoded
        }
        return labelStr
      }
    }
    return asciiLabels.joined(separator: ".")
  }

  private static func encodeDigit(_ d: Int) -> Character {
    if d < 26 {
      return Character(UnicodeScalar(d + 97)!)  // 'a'..'z'
    } else if d < 36 {
      return Character(UnicodeScalar(d - 26 + 48)!)  // '0'..'9'
    }
    fatalError("Invalid digit")
  }

  private static func adapt(_ delta: Int, _ numpoints: Int, _ firsttime: Bool) -> Int {
    var d = delta
    if firsttime {
      d = d / 700
    } else {
      d = d / 2
    }
    d += d / numpoints
    var k = 0
    while d > ((36 - 1) * 26) / 2 {
      d = d / (36 - 1)
      k += 36
    }
    return k + ((36 - 1 + 1) * d) / (d + 38)
  }
}
