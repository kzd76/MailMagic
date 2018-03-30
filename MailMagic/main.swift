//
//  main.swift
//  MailMagic
//
//  Created by Szternák Barna on 2018. 03. 23..
//  Copyright © 2018. Szternák Barna. All rights reserved.
//

import Foundation
import SQLite3

var isLog = false
var logPath = "mailmagic.log"


// =====================================
//             Log writer
// =====================================

func writeLog(_ output: String, to filePath: String) {
    if isLog {
        let stringToWrite = output.appending("\n")
        if let data = stringToWrite.data(using: .utf8) {
            if let fileHandle = FileHandle(forWritingAtPath: filePath) {
                defer {
                    fileHandle.closeFile()
                }
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                
            } else {
                let fileURL = URL(fileURLWithPath: filePath)
                do {
                    try data.write(to: fileURL)
                } catch {
                    //
                }
            }
        }
    }
}


// =====================================
//             Open Database
// =====================================

func openDatabase(from mydbPath: String) -> OpaquePointer? {
    var db : OpaquePointer? = nil
    
    if sqlite3_open(mydbPath, &db) == SQLITE_OK {
        writeLog("Successfully opened connection to database at \(mydbPath)", to: logPath)
        return db
    } else {
        print("Unable to open database at \(mydbPath)")
    }
    return nil
}

// =====================================
//              Check Tables
// =====================================

func checkTables(in mydb: OpaquePointer?) -> Bool {
    var checkTableStatement : OpaquePointer? = nil
    
    let checkTableString = "SELECT count(filepath) FROM mail"
    
    if sqlite3_prepare_v2(mydb, checkTableString, -1, &checkTableStatement, nil) == SQLITE_OK {
        if sqlite3_step(checkTableStatement) == SQLITE_ROW {
            writeLog("Mail table found.", to: logPath)
            sqlite3_finalize(checkTableStatement)
            return true
        } else {
            print("No mail table was found.")
            sqlite3_finalize(checkTableStatement)
            return false
        }
    } else {
        print("Check table statement could not be prepared.")
    }
    
    sqlite3_finalize(checkTableStatement)
    return false
}

// =====================================
//              Set Tables
// =====================================

func setTables(in mydb: OpaquePointer?) -> Bool {
    var createTableStatement : OpaquePointer? = nil
    
    let createTableString = """
        CREATE TABLE mail (
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        sentdate TEXT NOT NULL,
        mailsubject TEXT NOT NULL,
        mailfrom TEXT,
        mailto TEXT,
        tags TEXT,
        raw TEXT,
        simplified TEXT,
        hash TEXT,
        filepath TEXT NOT NULL
        );
    """
    
    if sqlite3_prepare_v2(mydb, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
        if sqlite3_step(createTableStatement) == SQLITE_DONE {
            writeLog("Mail table created.", to: logPath)
            sqlite3_finalize(createTableStatement)
            return true
        } else {
            print("Could not create mail table.")
            sqlite3_finalize(createTableStatement)
            return false
        }
    } else {
        print("Create table statement could not be prepared.")
    }
    
    sqlite3_finalize(createTableStatement)
    return false
}



// =====================================
//        Collect mails from path
// =====================================

func getMailsFromPath(path : String) -> [String]{
    //print("Analyzing path: \(path)")
    var result = [String]()
    do {
        let contents = try FileManager.default.contentsOfDirectory(atPath: path)
        
        for content in contents {
            if let _ = content.range(of: ".eml") {
                result.append("\(path)/\(content)")
            }
            
            var isDir : ObjCBool = false
            
            let isExists = FileManager.default.fileExists(atPath: "\(path)/\(content)", isDirectory: &isDir)
            
            if isExists && isDir.boolValue {
                result.append(contentsOf: getMailsFromPath(path: "\(path)/\(content)"))
            }
        }
    } catch {
        print("Something went wrong while processing this directory: \(path) - \(error.localizedDescription)")
    }
    
    return result
}

// =====================================
//             Clean Base64
// =====================================

func cleanBase64(input: String) -> String {
    var result = input
    
    while let sr = result.range(of: "=?UTF-8?B?") {
        let sp = sr.upperBound //input.index(after: )
        let wholeBasePart = String(result[sp...])
        if let ep = wholeBasePart.index(of: "?") {
            let basePart = String(wholeBasePart[...wholeBasePart.index(before: ep)])
            //print(basePart)
            
            if let decodedData = Data(base64Encoded: basePart) {
                if let decodedString = String(data: decodedData, encoding: .utf8) {
                    //print(decodedString)  
                    var beforeResult = ""
                    var afterResult = ""
                    if sr.lowerBound > result.startIndex {
                        beforeResult = String(result[...result.index(before: sr.lowerBound)])
                    }
                    
                    if let er = wholeBasePart.range(of: "?=") {
                        afterResult = String(wholeBasePart[er.upperBound...])
                    }
                    
                    result = beforeResult + decodedString + afterResult
                }
            }
        }
    }
    
    while let sr = result.range(of: "=?utf-8?B?") {
        let sp = sr.upperBound //input.index(after: )
        let wholeBasePart = String(result[sp...])
        if let ep = wholeBasePart.index(of: "?") {
            let basePart = String(wholeBasePart[...wholeBasePart.index(before: ep)])
            //print(basePart)
            
            if let decodedData = Data(base64Encoded: basePart) {
                if let decodedString = String(data: decodedData, encoding: .utf8) {
                    //print(decodedString)
                    var beforeResult = ""
                    var afterResult = ""
                    if sr.lowerBound > result.startIndex {
                        beforeResult = String(result[...result.index(before: sr.lowerBound)])
                    }
                    //else {
                    //    beforeResult = String(result[...sr.lowerBound])
                    //}
                    
                    if let er = wholeBasePart.range(of: "?=") {
                        afterResult = String(wholeBasePart[er.upperBound...])
                    }
                    
                    result = beforeResult + decodedString + afterResult
                }
            }
        }
    }
    
    while let sr = result.range(of: "=?utf-8?Q?") {
        let sp = sr.upperBound //input.index(after: )
        let wholeBasePart = String(result[sp...])
        if let ep = wholeBasePart.index(of: "?") {
            let basePart = String(wholeBasePart[...wholeBasePart.index(before: ep)])
            //print(basePart)
            
            var decodedString = QuotedPrintable.decode(string: basePart)
            
            if let decodedData = decodedString.data(using: .isoLatin2) {
                if let newDecodedString = String(data: decodedData, encoding: .utf8) {
                    decodedString = newDecodedString
                }
            }
            
            var beforeResult = ""
            var afterResult = ""
            if sr.lowerBound > result.startIndex {
                beforeResult = String(result[...result.index(before: sr.lowerBound)])
            }
            
            if let er = wholeBasePart.range(of: "?=") {
                afterResult = String(wholeBasePart[er.upperBound...])
            }
            
            result = beforeResult + decodedString + afterResult
        }
    }
    
    while let sr = result.range(of: "=?iso-8859-2?Q?") {
        let sp = sr.upperBound //input.index(after: )
        let wholeBasePart = String(result[sp...])
        if let ep = wholeBasePart.index(of: "?") {
            let basePart = String(wholeBasePart[...wholeBasePart.index(before: ep)])
            //print(basePart)
            
            var decodedString = QuotedPrintable.decode(string: basePart)
            
            if let decodedData = decodedString.data(using: .isoLatin2) {
                if let newDecodedString = String(data: decodedData, encoding: .utf8) {
                    decodedString = newDecodedString
                }
            }
            
            var beforeResult = ""
            var afterResult = ""
            if sr.lowerBound > result.startIndex {
                beforeResult = String(result[...result.index(before: sr.lowerBound)])
            }
            
            if let er = wholeBasePart.range(of: "?=") {
                afterResult = String(wholeBasePart[er.upperBound...])
            }
            
            result = beforeResult + decodedString + afterResult
        }
    }
    
    while let sr = result.range(of: "=?iso-8859-1?Q?") {
        let sp = sr.upperBound //input.index(after: )
        let wholeBasePart = String(result[sp...])
        if let ep = wholeBasePart.index(of: "?") {
            let basePart = String(wholeBasePart[...wholeBasePart.index(before: ep)])
            //print(basePart)
            
            var decodedString = QuotedPrintable.decode(string: basePart)
            
            if let decodedData = decodedString.data(using: .isoLatin1) {
                if let newDecodedString = String(data: decodedData, encoding: .utf8) {
                    decodedString = newDecodedString
                }
            }
            
            var beforeResult = ""
            var afterResult = ""
            if sr.lowerBound > result.startIndex {
                beforeResult = String(result[...result.index(before: sr.lowerBound)])
            }
            
            if let er = wholeBasePart.range(of: "?=") {
                afterResult = String(wholeBasePart[er.upperBound...])
            }
            
            result = beforeResult + decodedString + afterResult
            
            //beforeResult.appending(decodedString).appending(afterResult)
        }
    }
    
    return result
}

// =====================================
//             Format field
// =====================================

func formatField(input: String) -> String {
    var result = cleanBase64(input: input)
    
    result = result.replacingOccurrences(of: "\t ", with: " ")
    result = result.replacingOccurrences(of: "\t", with: " ")
    result = result.replacingOccurrences(of: "'", with: "''")
    
    result = result.replacingOccurrences(of: "\"", with: "")
    //result = result.replacingOccurrences(of: "=", with: "")
    result = result.replacingOccurrences(of: ",", with: "")
    
    return result
}

// =====================================
//             Process mails
// =====================================


func processMails(_ mailPaths: [String], inDatabase mydb: OpaquePointer?) {
    var totalMails = 0
    var newMails = 0
    var recordedMails = 0
    var oldMails = 0
    var errorMails = 0
    
    for mailPath in mailPaths {
        totalMails = totalMails + 1
        let percentage = Double(totalMails * 100) / Double(mailPaths.count)
        let percentageString = String(format: "%.02f%%", percentage)
        let fives = Int(percentage / 5)
        var progressString = "["
        for i in 1 ... 20 {
            if i <= fives {
                progressString.append("*")
            } else {
                progressString.append(" ")
            }
        }
        progressString.append("]")
        progressString = "\(progressString) - \(percentageString)"
        print("", terminator: "\r")
        print(progressString, terminator: "")
        fflush(__stdoutp)
        
        writeLog("\n\n----------\nProcessing mail at \(mailPath)", to: logPath)
        if let mail = StreamReader(path: mailPath, delimiter: "\r") {
            var canContinue = true
            
            var isDate = false
            var isSubject = false
            var isFrom = false
            var isTo = false
            var isContentType = false
            
            var isMimeHeader = false
            var isMimePart = false
            //var isMimeContentType = false
            
            var mailDate = ""
            var mailSubject = ""
            var mailFrom = ""
            var mailTo = ""
            var mailContentType = ""
            
            //var mimeContentType = ""
            var mimePart = ""
            
            var mimeBoundary = ""
            
            while canContinue {
                if let line = mail.nextLine() {
                    if line.isEmpty {
                        if !isMimeHeader && !isMimePart {
                            if let br = mailContentType.range(of: "boundary=\"") {
                                mimeBoundary = String(mailContentType[br.upperBound...])
                                if mimeBoundary.last == "\"" {
                                    mimeBoundary = String(mimeBoundary.dropLast())
                                    //print("Boundary changed to: \(mimeBoundary)")
                                    mailContentType = ""
                                }
                            }
                        }
                        
                        if isMimeHeader {
                            isMimeHeader = false
                            if let br = mailContentType.range(of: "boundary=\"") {
                                mimeBoundary = String(mailContentType[br.upperBound...])
                                if mimeBoundary.last == "\"" {
                                    mimeBoundary = String(mimeBoundary.dropLast())
                                    //print("Boundary changed to: \(mimeBoundary)")
                                    mailContentType = ""
                                }
                            }
                            
                            if let _ = mailContentType.range(of: "text/plain") {
                                isMimePart = true
                            }
                        }
                        
                        //canContinue = false
                        //print("----------\n\n")
                    }
                    //print(line)
                    
                    if line == "--\(mimeBoundary)" {
                        if !isMimePart {
                            isMimeHeader = true
                        } else {
                            isMimePart = false
                        }
                        
                    }
                    
                    if line == "--\(mimeBoundary)--" {
                        isMimePart = false
                    }
                    
                    if line.first == "\t" || line.first == " " {
                        if isDate {
                            mailDate = mailDate.appending(line)
                            //print("New date line: \(line)")
                        }
                        if isSubject {
                            mailSubject = mailSubject.appending(line)
                            //print("New subject line: \(line)")
                        }
                        if isFrom {
                            mailFrom = mailFrom.appending(line)
                            //print("New from line: \(line)")
                        }
                        if isTo {
                            mailTo = mailTo.appending(line)
                            //print("New to line: \(line)")
                        }
                        if isContentType {
                            mailContentType = mailContentType.appending(line)
                            //print("New content type line: \(line)")
                        }
                    } else {
                        isDate = false
                        isSubject = false
                        isFrom = false
                        isTo = false
                        isContentType = false
                    }
                    
                    if !isMimePart {
                        let lineParts = line.split(separator: ":")
                        
                        if lineParts.count > 0 {
                            var rest = ""
                            for i in 1..<lineParts.count {
                                rest = rest.appending((lineParts[i]))
                                if i < lineParts.count - 1 {
                                    rest = rest.appending(":")
                                }
                            }
                            
                            rest = String(rest.dropFirst())
                            
                            if lineParts[0] == "Date" {
                                isDate = true
                                isSubject = false
                                isFrom = false
                                isTo = false
                                isContentType = false
                                mailDate = rest
                                //print("Date is: \"\(rest)\"")
                            }
                            
                            if lineParts[0] == "Subject" {
                                isDate = false
                                isSubject = true
                                isFrom = false
                                isTo = false
                                isContentType = false
                                mailSubject = rest
                                //print("Subject is: \"\(rest)\"")
                            }
                            
                            if lineParts[0] == "From" {
                                isDate = false
                                isSubject = false
                                isFrom = true
                                isTo = false
                                isContentType = false
                                mailFrom = rest
                                //print("From is: \"\(rest)\"")
                            }
                            
                            if lineParts[0] == "To" {
                                isDate = false
                                isSubject = false
                                isFrom = false
                                isTo = true
                                isContentType = false
                                mailTo = rest
                                //print("To is: \"\(rest)\"")
                            }
                            
                            if lineParts[0] == "Content-type" {
                                isDate = false
                                isSubject = false
                                isFrom = false
                                isTo = false
                                isContentType = true
                                mailContentType = rest
                                //print("Content type is: \"\(rest)\"")
                            }
                        }
                    } else {
                        if isMimePart {
                            mimePart = mimePart.appending("\r")
                            mimePart = mimePart.appending(line)
                        }
                    }
                } else {
                    canContinue = false
                }
            }
            
            mailDate = formatField(input: mailDate)
            mailSubject = formatField(input: mailSubject)
            mailFrom = formatField(input: mailFrom)
            mailTo = formatField(input: mailTo)
            
            if mailSubject.isEmpty {
                mailSubject = " "
            }
            
            if !mailDate.isEmpty {
                writeLog("    Date is \(mailDate)", to: logPath)
                if !mailSubject.isEmpty {
                    writeLog("    Subject is \(mailSubject)", to: logPath)
                    if !mailFrom.isEmpty {
                        writeLog("    From is \(mailFrom)", to: logPath)
                        
                        let dbMailPath = mailPath.replacingOccurrences(of: "'", with: "''")
                        
                        let selectStatementString = "SELECT filepath FROM mail WHERE filepath = '\(dbMailPath)'"
                        
                        var selectStatement : OpaquePointer? = nil
                        
                        if sqlite3_prepare_v2(mydb, selectStatementString, -1, &selectStatement, nil) == SQLITE_OK {
                            if sqlite3_step(selectStatement) == SQLITE_ROW {
                                writeLog("Mail already processed from file at \(mailPath)", to: logPath)
                                oldMails = oldMails + 1
                            } else {
                                newMails = newMails + 1
                                writeLog("New unprocessed mail found at \(mailPath)", to: logPath)
                                
                                if !mimePart.isEmpty {
                                    
                                    mimePart = mimePart.replacingOccurrences(of: "=C2=B7       ", with: "- ")
                                    mimePart = mimePart.replacingOccurrences(of: "=E2=80=9C", with: "\"")
                                    mimePart = mimePart.replacingOccurrences(of: "=E2=80=9D", with: "\"")
                                    mimePart = mimePart.replacingOccurrences(of: "=E2=80=99", with: "'")
                                    mimePart = mimePart.replacingOccurrences(of: "=E2=80=A6", with: "...")
                                    
                                    
                                    mimePart = QuotedPrintable.decode(string: mimePart)
                                    
                                    if let mimeData = mimePart.data(using: .isoLatin1) {
                                        if let newMimePart = String(data: mimeData, encoding: .utf8) {
                                            mimePart = newMimePart
                                        }
                                    }
                                    
                                    //mimePart = cleanQuotedPrintable(input: mimePart)
                                    
                                    mimePart = mimePart.replacingOccurrences(of: "\r \r\r", with: "\\r")
                                    mimePart = mimePart.replacingOccurrences(of: "\r", with: "\\r")
                                    mimePart = mimePart.replacingOccurrences(of: "\n", with: "\\n")
                                    mimePart = mimePart.replacingOccurrences(of: "\t", with: "\\t")
                                    mimePart = mimePart.replacingOccurrences(of: "'", with: "''")
                                }
                                
                                let insertStatementString = "INSERT INTO mail (sentdate, mailsubject, mailfrom, mailto, simplified, filepath) VALUES ('\(mailDate)', '\(mailSubject)', '\(mailFrom)', '\(mailTo)', '\(mimePart)', '\(dbMailPath)');"
                                
                                var insertStatement: OpaquePointer? = nil
                                
                                if sqlite3_prepare_v2(mydb, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
                                    /*
                                     sqlite3_bind_text(insertStatement, 1, mailDate, -1, nil)
                                     sqlite3_bind_text(insertStatement, 2, mailSubject, -1, nil)
                                     sqlite3_bind_text(insertStatement, 3, mailFrom, -1, nil)
                                     sqlite3_bind_text(insertStatement, 4, mailTo, -1, nil)
                                     sqlite3_bind_blob(insertStatement, 5, mimePart, Int32(mimePart.lengthOfBytes(using: String.Encoding.ascii)), nil)
                                     sqlite3_bind_text(insertStatement, 6, mailPath, -1, nil)
                                     */
                                    
                                    if sqlite3_step(insertStatement) == SQLITE_DONE {
                                        writeLog("Successfully inserted row.", to: logPath)
                                        recordedMails = recordedMails + 1
                                    } else {
                                        writeLog("Could not insert row.", to: logPath)
                                        errorMails = errorMails + 1
                                    }
                                    
                                    sqlite3_reset(insertStatement)
                                } else {
                                    writeLog("INSERT statement could not be prepared.", to: logPath)
                                    errorMails = errorMails + 1
                                }
                                
                                sqlite3_finalize(insertStatement)
                            }
                            
                            sqlite3_reset(selectStatement)
                        }
                        
                        sqlite3_finalize(selectStatement)
                    } else {
                        writeLog("No sender found in mail.", to: logPath)
                        errorMails = errorMails + 1
                    }
                }
            } else {
                writeLog("No date found in mail.", to: logPath)
                errorMails = errorMails + 1
            }
        }
        writeLog("----------", to: logPath)
    }
    
    print("\n\n  Total: \(totalMails)\n  Found in db: \(oldMails)\n  New: \(newMails)\n  Recoded: \(recordedMails)\n  Errors: \(errorMails) \n")
}

// =====================================
//             Search mails
// =====================================


func searchMails(keyWords: String, inDatabase mydb : OpaquePointer?) {
    let keyWordArray = keyWords.split(separator: " ")
    for word in keyWordArray {
        if word.range(of: "from:")?.lowerBound == word.startIndex {
            print("New query: from field")
        }
        
        var selectStatement : OpaquePointer? = nil
        
        var selectStatementString = "SELECT filepath FROM mail WHERE mailfrom like '%\(String(word))%'"
        
        if sqlite3_prepare_v2(mydb, selectStatementString, -1, &selectStatement, nil) == SQLITE_OK {
            print("Results in from field:")
            while sqlite3_step(selectStatement) == SQLITE_ROW {
                if let queryResultCol1 = sqlite3_column_text(selectStatement, 0) {
                    let sText = String(cString: queryResultCol1)
                    print("  \(sText)")
                } else {
                    print("Unable to read from the selected record")
                }
            }
        }
        sqlite3_finalize(selectStatement)
        
        selectStatementString = "SELECT filepath FROM mail WHERE mailto like '%\(String(word))%'"
        
        if sqlite3_prepare_v2(mydb, selectStatementString, -1, &selectStatement, nil) == SQLITE_OK {
            print("Results in to field:")
            while sqlite3_step(selectStatement) == SQLITE_ROW {
                if let queryResultCol1 = sqlite3_column_text(selectStatement, 0) {
                    let sText = String(cString: queryResultCol1)
                    print("  \(sText)")
                } else {
                    print("Unable to read from the selected record")
                }
            }
        }
        sqlite3_finalize(selectStatement)
        
        selectStatementString = "SELECT filepath FROM mail WHERE mailsubject like '%\(String(word))%'"
        
        if sqlite3_prepare_v2(mydb, selectStatementString, -1, &selectStatement, nil) == SQLITE_OK {
            print("Results in subject field:")
            while sqlite3_step(selectStatement) == SQLITE_ROW {
                if let queryResultCol1 = sqlite3_column_text(selectStatement, 0) {
                    let sText = String(cString: queryResultCol1)
                    print("  \(sText)")
                } else {
                    print("Unable to read from the selected record")
                }
            }
        }
        sqlite3_finalize(selectStatement)
        
        selectStatementString = "SELECT filepath FROM mail WHERE simplified like '%\(String(word))%'"
        
        if sqlite3_prepare_v2(mydb, selectStatementString, -1, &selectStatement, nil) == SQLITE_OK {
            print("Results in mail body field:")
            while sqlite3_step(selectStatement) == SQLITE_ROW {
                if let queryResultCol1 = sqlite3_column_text(selectStatement, 0) {
                    let sText = String(cString: queryResultCol1)
                    print("  \(sText)")
                } else {
                    print("Unable to read from the selected record")
                }
            }
        }
        sqlite3_finalize(selectStatement)
    }
}


// =====================================
//          Search with select
// =====================================


func searchMailsWithSelect(selectString: String, inDatabase mydb : OpaquePointer?) {
    let mySelectString = selectString.replacingOccurrences(of: "\"", with: "")
    
    if mySelectString.uppercased().range(of: "WHERE")?.lowerBound == mySelectString.startIndex {
        var selectStatement : OpaquePointer? = nil
        
        let selectStatementString = "SELECT filepath FROM mail \(mySelectString)"
        
        if sqlite3_prepare_v2(mydb, selectStatementString, -1, &selectStatement, nil) == SQLITE_OK {
            print("Simplified content:")
            while sqlite3_step(selectStatement) == SQLITE_ROW {
                if let queryResultCol1 = sqlite3_column_text(selectStatement, 0) {
                    let sText = String(cString: queryResultCol1)
                    print("  \(sText)")
                } else {
                    print("Unable to read from the selected record")
                }
            }
        }
    
        sqlite3_finalize(selectStatement)
    }
}

// =====================================
//           Get mail content
// =====================================


func getMailContent(mailPath: String, inDatabase mydb : OpaquePointer?) {
    
    let myMailPath = mailPath.replacingOccurrences(of: "\"", with: "")
    
    var selectStatement : OpaquePointer? = nil
    
    let selectStatementString = "SELECT * FROM mail WHERE filepath like '%\(myMailPath)%'"
    
    if sqlite3_prepare_v2(mydb, selectStatementString, -1, &selectStatement, nil) == SQLITE_OK {
        while sqlite3_step(selectStatement) == SQLITE_ROW {
            print("\n============")
            if let queryResultCol1 = sqlite3_column_text(selectStatement, 9) {
                var sText = String(cString: queryResultCol1)
                //sText = sText.replacingOccurrences(of: "\r \r\r", with: "\\r")
                sText = sText.replacingOccurrences(of: "\\r", with: "\n")
                sText = sText.replacingOccurrences(of: "\\n", with: "\n")
                sText = sText.replacingOccurrences(of: "\\t", with: "\t")
                //sText = sText.replacingOccurrences(of: "'", with: "''")
                print("  \(sText)")
            } else {
                print("Unable to read from the selected record")
            }
            print("============\n")
            print("From:", terminator: "")
            if let queryResultCol1 = sqlite3_column_text(selectStatement, 3) {
                var sText = String(cString: queryResultCol1)
                //sText = sText.replacingOccurrences(of: "\r \r\r", with: "\\r")
                sText = sText.replacingOccurrences(of: "\\r", with: "\n")
                sText = sText.replacingOccurrences(of: "\\n", with: "\n")
                sText = sText.replacingOccurrences(of: "\\t", with: "\t")
                //sText = sText.replacingOccurrences(of: "'", with: "''")
                print("  \(sText)")
            } else {
                print("Unable to read from the selected record")
            }
            print("To: ", terminator: "")
            if let queryResultCol1 = sqlite3_column_text(selectStatement, 4) {
                var sText = String(cString: queryResultCol1)
                //sText = sText.replacingOccurrences(of: "\r \r\r", with: "\\r")
                sText = sText.replacingOccurrences(of: "\\r", with: "\n")
                sText = sText.replacingOccurrences(of: "\\n", with: "\n")
                sText = sText.replacingOccurrences(of: "\\t", with: "\t")
                //sText = sText.replacingOccurrences(of: "'", with: "''")
                print("  \(sText)")
            } else {
                print("Unable to read from the selected record")
            }
            print("Subject:", terminator: "")
            if let queryResultCol1 = sqlite3_column_text(selectStatement, 2) {
                var sText = String(cString: queryResultCol1)
                //sText = sText.replacingOccurrences(of: "\r \r\r", with: "\\r")
                sText = sText.replacingOccurrences(of: "\\r", with: "\n")
                sText = sText.replacingOccurrences(of: "\\n", with: "\n")
                sText = sText.replacingOccurrences(of: "\\t", with: "\t")
                //sText = sText.replacingOccurrences(of: "'", with: "''")
                print("  \(sText)")
            } else {
                print("Unable to read from the selected record")
            }
            print("Sent:", terminator: "")
            if let queryResultCol1 = sqlite3_column_text(selectStatement, 1) {
                var sText = String(cString: queryResultCol1)
                //sText = sText.replacingOccurrences(of: "\r \r\r", with: "\\r")
                sText = sText.replacingOccurrences(of: "\\r", with: "\n")
                sText = sText.replacingOccurrences(of: "\\n", with: "\n")
                sText = sText.replacingOccurrences(of: "\\t", with: "\t")
                //sText = sText.replacingOccurrences(of: "'", with: "''")
                print("  \(sText)")
            } else {
                print("Unable to read from the selected record")
            }
            print("-----\n")
            if let queryResultCol1 = sqlite3_column_text(selectStatement, 7) {
                var sText = String(cString: queryResultCol1)
                //sText = sText.replacingOccurrences(of: "\r \r\r", with: "\\r")
                sText = sText.replacingOccurrences(of: "\\r", with: "\n")
                sText = sText.replacingOccurrences(of: "\\n", with: "\n")
                sText = sText.replacingOccurrences(of: "\\t", with: "\t")
                //sText = sText.replacingOccurrences(of: "'", with: "''")
                print("  \(sText)")
            } else {
                print("Unable to read from the selected record")
            }
        }
    }
    
    sqlite3_finalize(selectStatement)
}


// =====================================
//               Main part
// =====================================

//print("Hello, World!")

let args = CommandLine.arguments

//print(FileManager.default.currentDirectoryPath)

//print((args[0] as NSString).deletingLastPathComponent)


if let dbPathIndex = args.index(of: "-l") {
    if dbPathIndex < args.count - 1 {
        let value = args[dbPathIndex + 1]
        if !(value.first == "-") {
            logPath = value
            var isDir : ObjCBool = false
            let isLogExisting = FileManager.default.fileExists(atPath: logPath, isDirectory: &isDir)
            if (isLogExisting && !isDir.boolValue) || !isLogExisting {
                isLog = true
            }
        }
    }
}


var dbPath = "mails.sqlite"

if let dbPathIndex = args.index(of: "-d") {
    if dbPathIndex < args.count - 1 {
        let value = args[dbPathIndex + 1]
        if !(value.first == "-") {
            dbPath = value
        }
    }
}

if let myDatabase = openDatabase(from: dbPath) {
    
    var continueFlag = false
    
    if !checkTables(in: myDatabase) {
        if let _ = args.index(of: "-c") {
            if setTables(in: myDatabase) {
                continueFlag = true
            } else {
                print("Unable to set the necessary tables, quitting.")
                exit(-1)
            }
        } else {
            print("Necessary tables were not found. Please execute the app with -c switch to create the tables.")
            exit(-1)
        }
    } else {
        continueFlag = true
    }
    
    if continueFlag {
        for arg in args {
            if arg.first == "-" {
                if let argIndex = args.index(of: arg) {
                    if argIndex < args.count - 1 {
                        let value = args[argIndex + 1]
                        if !(value.first == "-") {
                            let function = String(arg.dropFirst())
                            //print("\(function): \(value)")
                            
                            if function == "p" {
                                let basePath = value
                                let mailPaths = getMailsFromPath(path: basePath)
                                writeLog("Total mails on path: \(mailPaths.count)", to: logPath)
                                print("Found \(mailPaths.count) mails. Processing ... ")
                                processMails(mailPaths, inDatabase: myDatabase)
                            }
                            
                            if function == "f" {
                                searchMails(keyWords: value, inDatabase: myDatabase)
                            }
                            
                            if function == "fw" {
                                searchMailsWithSelect(selectString: value, inDatabase: myDatabase)
                            }
                            
                            if function == "g" {
                                getMailContent(mailPath: value, inDatabase: myDatabase)
                            }
                        }
                    }
                }
            }
        }
    }
}


