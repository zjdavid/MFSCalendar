//
//  Next_Class.swift
//  Next Class
//
//  Created by 戴元平 on 9/16/20.
//  Copyright © 2020 David. All rights reserved.
//

import WidgetKit
import SwiftUI
import Intents
import SwiftDate

struct Provider: IntentTimelineProvider {
    @State var listClasses = school.classesOnADayAfter(date: Date())
    let path = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.dwei.MFSCalendar")!.path
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationIntent(), nextClass: nil)
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), configuration: configuration, nextClass: nil)
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        let listClasses = school.classesOnADayAfter(date: Date())
        if listClasses.isEmpty {  // No Class on This Day.
            let entry = SimpleEntry(date: Date(), configuration: configuration, nextClass: nil)
//            let region = Region(zone: TimeZone(identifier: "America/New_York")!)
            let endDate = Date() + 5.minutes
            let timeLine = Timeline(entries: [entry], policy: .after(endDate.date))
            completion(timeLine)
            return
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        SwiftDate.defaultRegion = Region(zone: TimeZone(identifier: "America/New_York")!)
        formatter.dateFormat = "M/dd/yyyy hh:mm a"
        
        let fileManager = FileManager.default
        
        for (index, classObject) in listClasses.enumerated() {
            print(listClasses)
            var startTime: Date? {
                if index == 0 {
                    let startTimeString = classObject["start"] as? String ?? ""
                    let startDate = formatter.date(from: startTimeString)
                    if startDate != nil && startDate! < Date() {  // The class has already started
                        return nil
                    }
                    return Date()
                } else {
                    let startTimeString = listClasses[index - 1]["start"] as? String ?? ""
                    return formatter.date(from: startTimeString)
                }
            }
            
            guard startTime != nil else { continue }
            
            var imageName: String? = nil
            if let sectionID = self.getLeadSectionID(classDict: classObject) {
                let imagePath = self.path.appending("/\(sectionID)_profile.png")
                if fileManager.fileExists(atPath: imagePath) {
                    imageName = imagePath
                }
            }
            
            let nextClass = ClassDetail(className: classObject["className"] as? String ?? ""
                                        , imagePath: imageName)
            
            entries.append(
                SimpleEntry(date: startTime!,
                            configuration: configuration,
                            nextClass: nextClass)
            )
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    func getLeadSectionID(classDict: [String: Any]) -> Int? {
        if let leadSectionID = classDict["LeadSectionId"] as? Int {
            return leadSectionID
        } else if let sectionID = classDict["SectionId"] as? Int {
            return sectionID
        } else {
            return nil
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let nextClass: ClassDetail?
}

struct ClassDetail {
    let className: String
    let imagePath: String?
}

struct Next_ClassEntryView : View {
    var entry: SimpleEntry

    var body: some View {
        ZStack {
            Color(red: 1, green: 126/255, blue: 121/255)
            
            if entry.nextClass?.imagePath != nil {
                Image(uiImage: UIImage(contentsOfFile: entry.nextClass!.imagePath!)!)
                    .resizable()
//                    .blur(radius: 5.0)
                    .scaledToFill()
                
                Rectangle()
                    .foregroundColor(Color.black.opacity(0.4))
            }
            
            
            
            VStack(spacing: 20) {
                
                Text("Next Class")
                    .foregroundColor(.white)
                    .font(.headline)
                
                Text(entry.nextClass?.className ?? "")
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding()
                
            }
        }
    }
}

@main
struct Next_Class: Widget {
    let kind: String = "Next_Class"
    @State var listClasses = school.classesOnADayAfter(date: Date())
    @State var currentClass = [String: Any]()

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            Next_ClassEntryView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

struct Next_Class_Previews: PreviewProvider {
    static var previews: some View {
        Next_ClassEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent(), nextClass: ClassDetail(className: "a", imagePath: nil)))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
