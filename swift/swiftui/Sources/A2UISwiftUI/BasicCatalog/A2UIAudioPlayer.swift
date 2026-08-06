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
import AVFoundation
import OrderedJSON
import SwiftUI

/// SwiftUI component view for the A2UI Basic Catalog `AudioPlayer` component.
public struct A2UIAudioPlayer: View {
  public let node: Node

  @State private var isPlaying = false
  @State private var player: AVPlayer?

  public init(node: Node) {
    self.node = node
  }

  private var urlString: String {
    if let binding = node.properties["url"] as? DataBinding<String> {
      return binding.get()
    }
    if let str = node.properties["url"] as? String {
      return str
    }
    if let json = node.properties["url"] as? JSONValue {
      return json.stringValue ?? ""
    }
    return ""
  }

  private var descriptionText: String {
    if let binding = node.properties["description"] as? DataBinding<String> {
      return binding.get()
    }
    if let str = node.properties["description"] as? String {
      return str
    }
    if let json = node.properties["description"] as? JSONValue {
      return json.stringValue ?? ""
    }
    return ""
  }

  public var body: some View {
    HStack(spacing: 12) {
      Button(action: togglePlay) {
        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
          .font(.system(size: 36))
          .foregroundStyle(.tint)
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 4) {
        if !descriptionText.isEmpty {
          Text(descriptionText)
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
        } else {
          Text("Audio Track")
            .font(.subheadline.weight(.medium))
        }

        Text(urlString)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()
    }
    .padding(12)
    .background(Color.gray.opacity(0.12))
    .cornerRadius(10)
  }

  private func togglePlay() {
    if let url = URL(string: urlString), !urlString.isEmpty {
      if player == nil {
        player = AVPlayer(url: url)
      }
      if isPlaying {
        player?.pause()
        isPlaying = false
      } else {
        player?.play()
        isPlaying = true
      }
    }
  }
}
