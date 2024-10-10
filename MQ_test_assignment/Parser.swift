//
//  Parser.swift
//
//  Created by petrovichev maxim on 08.10.2024.
//

import Foundation

protocol ParserDelegate: AnyObject {
    func parser(_ parser: Parser, didMatchLine line: Data)
    func parserDidFinish(_ parser: Parser)
}

class Parser {
    private var receivedData = Data()
    private var partialLine = Data()
    private let maskPattern: String
    private let parsingQueue = DispatchQueue(label: "com.testAssignment.parserQueue")
    weak var delegate: ParserDelegate?
    
    var allDataBytesCount: Int = 0

    init(maskPattern: String) {
        self.maskPattern = maskPattern
    }

    func process(data: Data) {
        parsingQueue.async {
            self.receivedData.append(data)
            self.allDataBytesCount += data.count
            self.processReceivedData()
        }
    }

    func finishProcessing() {
        parsingQueue.async {
            self.processRemainingData()
            DispatchQueue.main.async {
                self.delegate?.parserDidFinish(self)
            }
        }
    }
    
    private func processReceivedData() {
        let newData = receivedData
        receivedData = Data()
        processPartialLine(with: newData, isDataComplete: false)
    }

    private func processRemainingData() {
        processPartialLine(with: Data(), isDataComplete: true)
        partialLine = Data()
    }

    private func processPartialLine(with data: Data, isDataComplete: Bool) {
        var lines = [Data]()
        var lineStartIndex = data.startIndex
        var index = data.startIndex

        while index < data.endIndex {
            let byte = data[index]
            if byte == 10 || byte == 13 {
                let lineEndIndex = index
                if byte == 13 /* '\r' */ && index + 1 < data.endIndex && data[data.index(after: index)] == 10 /* '\n' */ {
                    index = data.index(after: index) // Skip '\n'
                }

                var lineData = Data()
                lineData.append(partialLine)
                lineData.append(data[lineStartIndex..<lineEndIndex])
                lines.append(lineData)
                partialLine = Data()

                index = data.index(after: index)
                lineStartIndex = index
                continue
            }
            index = data.index(after: index)
        }

        if isDataComplete {
            var lineData = Data()
            lineData.append(partialLine)
            lineData.append(data[lineStartIndex..<data.endIndex])
            if allDataBytesCount != 0 {
                lines.append(lineData)
            }
            partialLine = Data()
        } else {
            partialLine.append(data[lineStartIndex..<data.endIndex])
        }

        for lineData in lines {
            processLine(lineData)
        }
    }

    private func processLine(_ lineData: Data) {
        let line = String(decoding: lineData, as: UTF8.self)
        if wildcardMatch(text: line, pattern: maskPattern) {
            DispatchQueue.main.async {
                self.delegate?.parser(self, didMatchLine: lineData)
            }
        }
    }

    // MARK: - Wildcard Matching

    private func wildcardMatch(text: String, pattern: String) -> Bool {
        if pattern.isEmpty {
            return text.isEmpty
        }
        
        if pattern.allSatisfy({ $0 == "*" }) {
            return true
        }
        
        var tIndex = text.startIndex
        var pIndex = pattern.startIndex
        var starIndex: String.Index? = nil
        var matchIndex: String.Index? = nil

        while tIndex < text.endIndex {
            if pIndex < pattern.endIndex &&
                (pattern[pIndex] == text[tIndex] || pattern[pIndex] == "?") {
                tIndex = text.index(after: tIndex)
                pIndex = pattern.index(after: pIndex)
            } else if pIndex < pattern.endIndex && pattern[pIndex] == "*" {
                starIndex = pIndex
                matchIndex = tIndex
                pIndex = pattern.index(after: pIndex)
            } else if let star = starIndex {
                pIndex = pattern.index(after: star)
                if let mIndex = matchIndex {
                    matchIndex = text.index(after: mIndex)
                    tIndex = matchIndex!
                }
            } else {
                return false
            }
        }

        while pIndex < pattern.endIndex && pattern[pIndex] == "*" {
            pIndex = pattern.index(after: pIndex)
        }

        return pIndex == pattern.endIndex
    }
}
