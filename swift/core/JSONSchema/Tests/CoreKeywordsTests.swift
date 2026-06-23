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

import JSONSchema
import Testing

struct CoreKeywordsTests {
  @Test func testTypeMatching() {
    let allowedNumber = JSONValue.array([.string("number")])
    let allowedInteger = JSONValue.array([.string("integer")])

    let numberEvaluator = TypeEvaluator(allowedTypes: allowedNumber)
    let integerEvaluator = TypeEvaluator(allowedTypes: allowedInteger)

    let floatVal = JSONValue.number(42.0)
    let intVal = JSONValue.integer(42)

    let context = ValidationContext()

    let numFloatRes = numberEvaluator.evaluate(instance: floatVal, context: context)
    let intFloatRes = integerEvaluator.evaluate(instance: floatVal, context: context)
    #expect(numFloatRes.isValid == true)
    #expect(intFloatRes.isValid == false)

    let numIntRes = numberEvaluator.evaluate(instance: intVal, context: context)
    let intIntRes = integerEvaluator.evaluate(instance: intVal, context: context)
    #expect(numIntRes.isValid == true)
    #expect(intIntRes.isValid == true)
  }

  @Test func testEnumValidation() {
    let enumSchema = JSONValue.array([.string("foo"), .integer(42)])
    let evaluator = EnumEvaluator(allowedValues: enumSchema)
    let context = ValidationContext()

    let fooRes = evaluator.evaluate(instance: .string("foo"), context: context)
    let numRes = evaluator.evaluate(instance: .integer(42), context: context)
    let barRes = evaluator.evaluate(instance: .string("bar"), context: context)

    #expect(fooRes.isValid == true)
    #expect(numRes.isValid == true)
    #expect(barRes.isValid == false)
  }

  @Test func testApplicability() {
    let maxEvaluator = MaximumEvaluator(limit: .integer(10))
    let context = ValidationContext()

    let res = maxEvaluator.evaluate(instance: .string("ignore me"), context: context)
    #expect(res.isValid == true)
  }

  @Test func testConstValidation() {
    let evaluator = ConstEvaluator(expectedValue: .string("hello"))
    let context = ValidationContext()

    let helloRes = evaluator.evaluate(instance: .string("hello"), context: context)
    let worldRes = evaluator.evaluate(instance: .string("world"), context: context)

    #expect(helloRes.isValid == true)
    #expect(worldRes.isValid == false)
  }

  @Test func testNumericBoundaries() {
    let context = ValidationContext()

    // Minimum & ExclusiveMinimum
    let minEvaluator = MinimumEvaluator(limit: .integer(5))
    let exclMinEvaluator = ExclusiveMinimumEvaluator(limit: .integer(5))

    let minValRes1 = minEvaluator.evaluate(instance: .integer(5), context: context)
    let minValRes2 = minEvaluator.evaluate(instance: .integer(4), context: context)
    let exclMinValRes1 = exclMinEvaluator.evaluate(instance: .integer(6), context: context)
    let exclMinValRes2 = exclMinEvaluator.evaluate(instance: .integer(5), context: context)

    #expect(minValRes1.isValid == true)
    #expect(minValRes2.isValid == false)
    #expect(exclMinValRes1.isValid == true)
    #expect(exclMinValRes2.isValid == false)

    // Maximum & ExclusiveMaximum
    let maxEvaluator = MaximumEvaluator(limit: .integer(10))
    let exclMaxEvaluator = ExclusiveMaximumEvaluator(limit: .integer(10))

    let maxValRes1 = maxEvaluator.evaluate(instance: .integer(10), context: context)
    let maxValRes2 = maxEvaluator.evaluate(instance: .integer(11), context: context)
    let exclMaxValRes1 = exclMaxEvaluator.evaluate(instance: .integer(9), context: context)
    let exclMaxValRes2 = exclMaxEvaluator.evaluate(instance: .integer(10), context: context)

    #expect(maxValRes1.isValid == true)
    #expect(maxValRes2.isValid == false)
    #expect(exclMaxValRes1.isValid == true)
    #expect(exclMaxValRes2.isValid == false)

    // MultipleOf
    let multEvaluator = MultipleOfEvaluator(divisor: .number(1.5))
    let multRes1 = multEvaluator.evaluate(instance: .number(4.5), context: context)
    let multRes2 = multEvaluator.evaluate(instance: .number(4.0), context: context)

    #expect(multRes1.isValid == true)
    #expect(multRes2.isValid == false)
  }

  @Test func testMathematicalEquality() {
    let constEvaluator = ConstEvaluator(expectedValue: .integer(42))
    let enumEvaluator = EnumEvaluator(allowedValues: .array([.integer(42)]))
    let context = ValidationContext()

    let floatVal = JSONValue.number(42.0)
    let constRes = constEvaluator.evaluate(instance: floatVal, context: context)
    let enumRes = enumEvaluator.evaluate(instance: floatVal, context: context)

    #expect(constRes.isValid == true)
    #expect(enumRes.isValid == true)
  }

  @Test func testPrecisionNumericBoundaries() {
    // 2^53 is 9007199254740992. Let's use 9007199254740993 and 9007199254740994.
    // If converted to Double, both 9007199254740993 and 9007199254740994 would be converted
    // to 9007199254740992 or 9007199254740994, losing their difference.
    let limit = JSONValue.integer(9_007_199_254_740_993)
    let instance = JSONValue.integer(9_007_199_254_740_994)
    let context = ValidationContext()

    let maxEvaluator = MaximumEvaluator(limit: limit)
    let minEvaluator = MinimumEvaluator(limit: instance)

    let maxRes = maxEvaluator.evaluate(instance: instance, context: context)
    let minRes = minEvaluator.evaluate(instance: limit, context: context)

    #expect(maxRes.isValid == false)
    #expect(minRes.isValid == false)
  }
}
