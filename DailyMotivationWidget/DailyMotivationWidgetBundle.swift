//
//  DailyMotivationWidgetBundle.swift
//  DailyMotivationWidget
//
//  Created by Hung Luong on 12/5/25.
//

import WidgetKit
import SwiftUI

@main
struct DailyMotivationWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyMotivationWidget()
        if #available(iOS 18.0, *) {
            DailyMotivationWidgetControl()
        }
        if #available(iOS 16.1, *) {
            DailyMotivationWidgetLiveActivity()
        }
    }
}
