//
//  CiraWidget.swift
//  CiraWidget
//
//  Widget configuration — supports both small and medium.
//

import WidgetKit
import SwiftUI

struct CiraWidget: Widget {
    let kind: String = "CiraWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CiraTimelineProvider()) { entry in
            CiraWidgetEntryView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("CIRA Posts")
        .description("See the latest post from friends")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
