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
import OrderedJSON
import SwiftUI

/// SwiftUI component view for the A2UI Basic Catalog `Icon` component.
public struct A2UIIcon: View {
  public let node: Node

  public init(node: Node) {
    self.node = node
  }

  private var iconName: String {
    if let binding = node.properties["name"] as? DataBinding<String> {
      return binding.get()
    }
    if let str = node.properties["name"] as? String {
      return str
    }
    if let json = node.properties["name"] as? JSONValue {
      if let str = json.stringValue { return str }
      if let svgPath = json["svgPath"]?.stringValue { return "svg:\(svgPath)" }
    }
    return ""
  }

  public var body: some View {
    let symbol = sfSymbolName(for: iconName)
    Image(systemName: symbol)
      .font(.system(size: 20))
      .frame(width: 24, height: 24)
      .accessibilityLabel(iconName)
  }

  private func sfSymbolName(for name: String) -> String {
    switch name {
    case "accountCircle": return "person.crop.circle"
    case "add": return "plus"
    case "arrowBack": return "arrow.backward"
    case "arrowForward": return "arrow.forward"
    case "attachFile": return "paperclip"
    case "calendarToday": return "calendar"
    case "call": return "phone"
    case "camera": return "camera"
    case "check": return "checkmark"
    case "close": return "xmark"
    case "delete": return "trash"
    case "download": return "arrow.down.to.line"
    case "edit": return "pencil"
    case "event": return "calendar.badge.clock"
    case "error": return "exclamationmark.circle"
    case "fastForward": return "forward.fill"
    case "favorite": return "heart.fill"
    case "favoriteOff": return "heart"
    case "folder": return "folder"
    case "help": return "questionmark.circle"
    case "home": return "house"
    case "info": return "info.circle"
    case "locationOn": return "mappin.and.ellipse"
    case "lock": return "lock"
    case "lockOpen": return "lock.open"
    case "mail": return "envelope"
    case "menu": return "line.3.horizontal"
    case "moreVert": return "ellipsis"
    case "moreHoriz": return "ellipsis"
    case "notifications": return "bell"
    case "notificationsOff": return "bell.slash"
    case "pause": return "pause.fill"
    case "payment": return "creditcard"
    case "person": return "person"
    case "phone": return "phone"
    case "photo": return "photo"
    case "play": return "play.fill"
    case "print": return "printer"
    case "refresh": return "arrow.clockwise"
    case "rewind": return "backward.fill"
    case "search": return "magnifyingglass"
    case "send": return "paperplane"
    case "settings": return "gearshape"
    case "share": return "square.and.arrow.up"
    case "shoppingCart": return "cart"
    case "skipNext": return "forward.end.fill"
    case "skipPrevious": return "backward.end.fill"
    case "star": return "star.fill"
    case "starHalf": return "star.leadinghalf.filled"
    case "starOff": return "star"
    case "stop": return "stop.fill"
    case "upload": return "arrow.up.to.line"
    case "visibility": return "eye"
    case "visibilityOff": return "eye.slash"
    case "volumeDown": return "speaker.wave.1"
    case "volumeMute": return "speaker.slash"
    case "volumeOff": return "speaker.slash"
    case "volumeUp": return "speaker.wave.3"
    case "warning": return "exclamationmark.triangle"
    default:
      return name.isEmpty ? "circle.fill" : name
    }
  }
}
