//
//  DailyMotivationWidgetLiveActivity.swift
//  DailyMotivationWidget
//
//  Created by Hung Luong on 12/5/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
struct DailyMotivationWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

@available(iOS 16.1, *)
struct DailyMotivationWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailyMotivationWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension DailyMotivationWidgetAttributes {
    fileprivate static var preview: DailyMotivationWidgetAttributes {
        DailyMotivationWidgetAttributes(name: "World")
    }
}

extension DailyMotivationWidgetAttributes.ContentState {
    fileprivate static var smiley: DailyMotivationWidgetAttributes.ContentState {
        DailyMotivationWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: DailyMotivationWidgetAttributes.ContentState {
         DailyMotivationWidgetAttributes.ContentState(emoji: "🤩")
     }
}

@available(iOS 16.1, *)
#Preview("Notification", as: .content, using: DailyMotivationWidgetAttributes.preview) {
   DailyMotivationWidgetLiveActivity()
} contentStates: {
    DailyMotivationWidgetAttributes.ContentState.smiley
    DailyMotivationWidgetAttributes.ContentState.starEyes
}

