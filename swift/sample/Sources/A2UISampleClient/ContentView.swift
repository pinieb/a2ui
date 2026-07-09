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
import JSONSchema
import OrderedJSON
import SwiftUI

/// The main content view for the A2UI sample client.
///
/// Hosts a `Surface` view, manages the `MessageProcessor` lifecycle,
/// and simulates receiving JSONL messages from a server.
public struct ContentView: View {
  @StateObject private var processor: MessageProcessor
  @State private var surfaceID: String?
  @State private var statusMessage = "Ready"
  @State private var initError: String?

  // Strong reference to keep the action handler alive (MessageProcessor
  // and SurfaceViewModel store it weakly).
  private let actionHandler: SampleActionHandler

  public init() {
    let handler = SampleActionHandler()
    self.actionHandler = handler

    let catalog: any ComponentCatalog
    do {
      catalog = try SampleCatalog()
    } catch {
      // Store the error instead of crashing; display it in the UI.
      catalog = EmptyCatalog()
      _processor = StateObject(
        wrappedValue: MessageProcessor(
          catalogs: ["default": catalog],
          actionHandler: handler
        )
      )
      _initError = State(initialValue: "Failed to create SampleCatalog: \(error)")
      return
    }

    _processor = StateObject(
      wrappedValue: MessageProcessor(
        catalogs: ["default": catalog],
        actionHandler: handler
      )
    )
  }

  public var body: some View {
    NavigationStack {
      VStack {
        if let initError {
          VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
              .font(.largeTitle)
              .foregroundStyle(.red)
            Text("Initialization Error")
              .font(.headline)
            Text(initError)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
          .padding()
        } else if let surfaceID, let vm = processor.getSurface(id: surfaceID) {
          Surface<SampleCatalogView>(
            viewModel: vm,
            catalogType: SampleCatalogView.self
          )
          .padding()
        } else {
          VStack(spacing: 8) {
            Image(systemName: "rectangle.dashed")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
            Text("No Active Surface")
              .font(.headline)
            Text("Tap a demo button below to create a surface.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .padding()
        }

        Divider()

        ScrollView {
          VStack(spacing: 12) {
            Button("Demo: Simple Text + Button") {
              runSimpleDemo()
            }
            .buttonStyle(.borderedProminent)

            Button("Demo: Form with Data Binding") {
              runFormDemo()
            }
            .buttonStyle(.bordered)

            Button("Demo: Card with Children") {
              runCardDemo()
            }
            .buttonStyle(.bordered)

            if let surfaceID {
              Button("Delete Surface", role: .destructive) {
                deleteSurface(surfaceID)
              }
              .buttonStyle(.bordered)
            }
          }
          .padding()
        }

        Text(statusMessage)
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.bottom, 8)
      }
      .navigationTitle("A2UI Sample")
    }
  }

  // MARK: - Demo Scenarios

  private func runSimpleDemo() {
    do {
      try processor.process(line: """
        {"createSurface": {"surfaceId": "demo1", "catalogId": "default"}}
        """)
      try processor.process(line: """
        {"updateComponents": {"surfaceId": "demo1", "components": [
          {"id": "root", "component": "column", "children": [
            "title", "btn"
          ]},
          {"id": "title", "component": "text", "text": "Hello from A2UI!"},
          {"id": "btn", "component": "button", "label": "Click Me", "onClick": {"event": {"name": "greet"}}}
        ]}}
        """)
      surfaceID = "demo1"
      statusMessage = "Simple demo loaded"
    } catch {
      statusMessage = "Error: \(error.localizedDescription)"
    }
  }

  private func runFormDemo() {
    do {
      try processor.process(line: """
        {"createSurface": {"surfaceId": "demo2", "catalogId": "default"}}
        """)
      try processor.process(line: """
        {"updateComponents": {"surfaceId": "demo2", "components": [
          {"id": "root", "component": "column", "children": ["nameField", "emailField", "subscribe", "submitBtn"]},
          {"id": "nameField", "component": "textField", "value": {"path": "/form/name"}, "placeholder": "Your name"},
          {"id": "emailField", "component": "textField", "value": {"path": "/form/email"}, "placeholder": "Your email"},
          {"id": "subscribe", "component": "checkBox", "checked": {"path": "/form/subscribe"}, "label": "Subscribe to updates"},
          {"id": "submitBtn", "component": "button", "label": {"path": "/form/submitLabel"}, "onClick": {"event": {"name": "submitForm"}}}
        ]}}
        """)
      try processor.process(line: """
        {"updateDataModel": {"surfaceId": "demo2", "path": "/form/name", "value": ""}}
        """)
      try processor.process(line: """
        {"updateDataModel": {"surfaceId": "demo2", "path": "/form/email", "value": ""}}
        """)
      try processor.process(line: """
        {"updateDataModel": {"surfaceId": "demo2", "path": "/form/subscribe", "value": false}}
        """)
      try processor.process(line: """
        {"updateDataModel": {"surfaceId": "demo2", "path": "/form/submitLabel", "value": "Submit Form"}}
        """)
      surfaceID = "demo2"
      statusMessage = "Form demo loaded — try typing in the fields"
    } catch {
      statusMessage = "Error: \(error.localizedDescription)"
    }
  }

  private func runCardDemo() {
    do {
      try processor.process(line: """
        {"createSurface": {"surfaceId": "demo3", "catalogId": "default"}}
        """)
      try processor.process(line: """
        {"updateComponents": {"surfaceId": "demo3", "components": [
          {"id": "root", "component": "column", "children": ["card1", "card2"]},
          {"id": "card1", "component": "card", "children": ["cardTitle1", "cardText1"]},
          {"id": "cardTitle1", "component": "text", "text": "Card One"},
          {"id": "cardText1", "component": "text", "text": "This is content inside a card."},
          {"id": "card2", "component": "card", "children": ["cardTitle2", "divider1", "cardBtn2"]},
          {"id": "cardTitle2", "component": "text", "text": "Card Two"},
          {"id": "divider1", "component": "divider"},
          {"id": "cardBtn2", "component": "button", "label": "Action", "onClick": {"event": {"name": "cardAction"}}}
        ]}}
        """)
      surfaceID = "demo3"
      statusMessage = "Card demo loaded"
    } catch {
      statusMessage = "Error: \(error.localizedDescription)"
    }
  }

  private func deleteSurface(_ id: String) {
    do {
      try processor.process(line: """
        {"deleteSurface": {"surfaceId": "\(id)"}}
        """)
      surfaceID = nil
      statusMessage = "Surface deleted"
    } catch {
      statusMessage = "Error: \(error.localizedDescription)"
    }
  }
}

/// An empty catalog used as a fallback when `SampleCatalog` fails to
/// initialize. Returns no schemas, themes, or functions.
private struct EmptyCatalog: ComponentCatalog {
  func schema(forType type: String) -> Schema? {
    nil
  }

  func makeTheme(jsonObject: JSONValue) -> (any SurfaceTheme)? {
    nil
  }

  func localFunction(for name: String) -> (any LocalFunction)? {
    nil
  }
}
