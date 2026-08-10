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

import XCTest

final class A2UISampleClientUITests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testFormattedTextDataBindingUpdates() throws {
    let app = XCUIApplication()
    app.launch()

    // 1. If currently showing a different sample (e.g. Complex Layout), pop back to Gallery list
    if !app.navigationBars["Formatted Text"].exists {
      let backButton = app.navigationBars.buttons.firstMatch
      if backButton.exists {
        backButton.tap()
      }

      // Select "Formatted Text" from gallery list
      let formattedTextCell =
        app.buttons["Formatted Text"].exists
        ? app.buttons["Formatted Text"] : app.staticTexts["Formatted Text"]
      XCTAssertTrue(
        formattedTextCell.waitForExistence(timeout: 5), "Formatted Text sample should be in list")
      formattedTextCell.tap()
    }

    // 2. Advance all steps (Step 1: createSurface, Step 2: updateComponents)
    let advanceButton = app.buttons["Advance"]
    XCTAssertTrue(
      advanceButton.waitForExistence(timeout: 5), "Advance button should exist on detail view")
    advanceButton.tap()  // Step 1 of 2

    XCTAssertTrue(
      advanceButton.waitForExistence(timeout: 5) && advanceButton.isEnabled,
      "Advance button should be enabled for step 2")
    advanceButton.tap()  // Step 2 of 2

    // 3. Find the text field
    let textField =
      app.textFields["Type something:"].exists
      ? app.textFields["Type something:"] : app.textFields.firstMatch
    XCTAssertTrue(textField.waitForExistence(timeout: 5), "TextField should be visible on Step 2")

    // 4. Type text into the text field
    textField.tap()
    textField.typeText("Hello A2UI")

    // 5. Verify the formatted text label below updates
    let updatedLabel = app.staticTexts["You typed: Hello A2UI"]
    XCTAssertTrue(
      updatedLabel.waitForExistence(timeout: 5),
      "Text component with formatString binding should update to 'You typed: Hello A2UI'"
    )
  }
}
