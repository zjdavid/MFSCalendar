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
    let path = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.dwei.MFSCalendar")!.path
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationIntent(), nextClass: nil, homework: nil, error: "MFS Mobile")
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), configuration: configuration, nextClass: nil, homework: nil, error: "MFS Mobile")
        completion(entry)
    }
    
    func completeWithError(for configuration: ConfigurationIntent, error: String) -> Timeline<SimpleEntry> {
        let entry = SimpleEntry(date: Date(), configuration: configuration, nextClass: nil, homework: nil, error: error)
        let endDate = Date() + 5.minutes
        let timeLine = Timeline(entries: [entry], policy: .after(endDate.date))
        return timeLine
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        let listClasses = school.classesOnADayAfter(date: Date())
        if listClasses.isEmpty {  // No Class on This Day or end of school day.
            HomeworkFetch().returnWithHomeworkCount(configuration: configuration, completionWithHomework: completion)
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
            
            let nextClass = ClassDetail(className: classObject["className"] as? String ?? "",
                                        imagePath: imageName,
                                        roomNumber: classObject["roomNumber"] as? String
                                        )
            
            entries.append(
                SimpleEntry(date: startTime!,
                            configuration: configuration,
                            nextClass: nextClass,
                            homework: nil,
                            error: nil)
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
    let homework: HomeworkData?
    let error: String?
}

struct ClassDetail {
    let className: String
    let imagePath: String?
    let roomNumber: String?
}

struct HomeworkData {
    var completed: Int
    var total: Int
}

struct HomeworkFetch {
    func completeWithError(for configuration: ConfigurationIntent, error: String) -> Timeline<SimpleEntry> {
        let entry = SimpleEntry(date: Date(), configuration: configuration, nextClass: nil, homework: nil, error: error)
        let endDate = Date() + 5.minutes
        let timeLine = Timeline(entries: [entry], policy: .after(endDate.date))
        return timeLine
    }
    
    func returnWithHomeworkCount(configuration: ConfigurationIntent, completionWithHomework: @escaping (Timeline<SimpleEntry>) -> ()) {
        guard loginAuthentication().success else {
            completionWithHomework(completeWithError(for: configuration, error: "Not logged in"))
            return
        }
        
        let daySelected = Date()
        var dayEnd = Date()
        var listClasses = [[String: Any]]()
        while listClasses.isEmpty {
            dayEnd = dayEnd + 1.days
            listClasses = school.getClassDataAt(date: dayEnd)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "M/d/yyyy"
        let daySelectedString = formatter.string(from: daySelected).addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let dayEndString = formatter.string(from: dayEnd).addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let url = Preferences().baseURL + "/api/DataDirect/AssignmentCenterAssignments/?format=json&filter=1&dateStart=\(daySelectedString)&dateEnd=\(dayEndString)&persona=2"
        print(url)
        let request = URLRequest(url: URL(string: url)!)
        
        let session = URLSession.shared
        let task: URLSessionDataTask = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if error == nil {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [[String: Any]] {
                        var homeworkData = HomeworkData(completed: 0, total: 0)
                        for homeworkRecord in json {
                            if homeworkRecord["assignment_status"] as? Int == 1 {
                                homeworkData.completed += 1
                            }
                            homeworkData.total += 1
                        }
                        
                        let entry = SimpleEntry(date: Date(),
                                                configuration: configuration,
                                                nextClass: nil,
                                                homework: homeworkData,
                                                error: nil)
                        let endDate = Date() + 5.minutes
                        let timeLine = Timeline(entries: [entry], policy: .after(endDate.date))
                        completionWithHomework(timeLine)
                    }
                } catch {
                    completionWithHomework(completeWithError(for: configuration, error: "Data parsing failed"))
                    NSLog("Data parsing failed")
                }
            } else {
                completionWithHomework(completeWithError(for: configuration, error: error!.localizedDescription))
            }
            
            completionWithHomework(completeWithError(for: configuration, error: "Unknown Error"))
        })

        task.resume()
    }
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
                if entry.nextClass != nil {
                    Text("Next Class")
                        .foregroundColor(.white)
                        .font(.headline)
                    
                    Text(entry.nextClass!.className)
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if entry.nextClass!.roomNumber != nil {
                        Text(entry.nextClass!.roomNumber!)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .font(.caption)
                    }
                    
                }
                
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
        Next_ClassEntryView(entry: SimpleEntry(date: Date(),
                                               configuration: ConfigurationIntent(),
                                               nextClass: ClassDetail(className: "a", imagePath: nil, roomNumber: nil),
                                               homework: nil,
                                               error: nil))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}