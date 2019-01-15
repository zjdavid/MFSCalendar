//
//  MFSClasses.swift
//  MFSMobile
//
//  Created by David Dai on 2/15/18.
//  Copyright © 2018 David. All rights reserved.
//

import Foundation

class MFS: School {
    
    func classesOnDay(day: Date) {
        
    }
    
    private func getClassDataAt(date: Date) -> [[String: Any]] {
        //var period = period
        var listClasses = [[String: Any]]()
        let day = dayCheck(date: date)
        
        let plistPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.dwei.MFSCalendar")!.path
        let fileName = "/Class" + day + ".plist"
        let path = plistPath.appending(fileName)
        
        guard let allClasses = NSArray(contentsOfFile: path) as? Array<Dictionary<String, Any>> else {
            return listClasses
        }
        
        listClasses = allClasses
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EE"
        let weekDay = dateFormatter.string(from: date)
        //let lunch = ["className": "Lunch", "roomNumber": "DH/C", "teacher": "", "period": 11] as [String: Any]
        if listClasses.count >= 6 && weekDay == "Wed" {
            let meetingForWorship = ["className": "Meeting For Worship", "roomNumber": "Meeting House", "teacher": "", "period": 4] as [String: Any]
            listClasses[3] = meetingForWorship
        }
        
        return listClasses
    }
    
    func classesOnADayAfter(time: Date) -> [[String: Any]] {
        let classData = getClassDataAt(date: time)
        
        if classData.isEmpty {
            return classData
        }
        
        let sortedClassData = classData.sorted { (a, b) -> Bool in
            return (a["startTime"] as? Int ?? 0) < (b["startTime"] as? Int ?? 0)
        }
        
        print(sortedClassData)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HHmm"
        let currentTime = Int(dateFormatter.string(from: time)) ?? 0
        
        let filteredData = sortedClassData.filter { (a) -> Bool in
            return (a["endTime"] as? Int ?? 0) > currentTime
        }
        
        return filteredData
    }
    
    
    
    func dayCheck(date: Date) -> String {
        var dayOfSchool: String? = nil
        let formatter = DateFormatter()
        let plistPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.dwei.MFSCalendar")!.path
        let path = plistPath.appending("/Day.plist")
        let dayDict = NSDictionary(contentsOfFile: path)
        formatter.dateFormat = "yyyyMMdd"
        let checkDate = formatter.string(from: date)
        
        dayOfSchool = dayDict?[checkDate] as? String ?? "No School"
        
        return dayOfSchool!
    }
}
