//
//  ResultsDataSource.swift
//
//  Created by petrovichev maxim on 08.10.2024.
//

import UIKit

class ResultsDataSource {
    private(set) var displayedLines: [String] = []
    private var lineOffsets: [UInt64] = []
    private let resultsFileURL: URL
    private let fileWriteQueue = DispatchQueue(label: "com.yourapp.fileWriteQueue")
    private var fileHandle: FileHandle?
    private let pageSize = 100
    private var currentPage = 0

    init(resultsFileURL: URL) throws {
        self.resultsFileURL = resultsFileURL
        try openResultsLog()
    }

    private func openResultsLog() throws {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: resultsFileURL.path) {
            try? fileManager.removeItem(atPath: resultsFileURL.path)
        }

        fileManager.createFile(atPath: resultsFileURL.path, contents: nil, attributes: nil)

        fileHandle = try FileHandle(forWritingTo: resultsFileURL)
    }
    
    func writeLineToLog(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        fileWriteQueue.async {
            var dataWithNewline = data
            dataWithNewline.append(0x0A)
            
            guard let fileHandle = self.fileHandle else {
                completion(.failure(NSError(domain: "FileError", code: 1, userInfo: [NSLocalizedDescriptionKey: "File is not open for writing"])))
                return
            }

            let offset = fileHandle.offsetInFile
            fileHandle.write(dataWithNewline)
            self.lineOffsets.append(offset)
            completion(.success(()))
        }
    }

    func loadNextPage(completion: @escaping () -> Void) {
        fileWriteQueue.async {
            let startLine = self.currentPage * self.pageSize
            let endLine = min(startLine + self.pageSize, self.lineOffsets.count)

            guard startLine < endLine else {
                // No data for loading
                return
            }

            let lineOffsetsCopy = self.lineOffsets

            for index in startLine..<endLine {
                if index < lineOffsetsCopy.count {
                    let startOffset = lineOffsetsCopy[index]
                    if let line = self.readLine(atOffset: startOffset) {
                        self.displayedLines.append(line)
                    }
                }
            }

            self.currentPage += 1
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    private func readLine(atOffset startOffset: UInt64) -> String? {
        guard let fileHandle = try? FileHandle(forReadingFrom: resultsFileURL) else {
            return nil
        }

        defer {
            fileHandle.closeFile()
        }

        let maxReadLength = 200

        fileHandle.seek(toFileOffset: startOffset)

        var data = fileHandle.readData(ofLength: maxReadLength)

        if let newlineIndex = data.firstIndex(of: 0x0A) { // 0x0A — '\n'
            data = data.subdata(in: data.startIndex..<newlineIndex)
        }

        let encoding = String.Encoding.windowsCP1251
        return String(data: data, encoding: encoding)
    }

    func reset() throws {
        try fileWriteQueue.sync {
            self.displayedLines.removeAll()
            self.lineOffsets.removeAll()
            self.currentPage = 0
            self.fileHandle?.closeFile()
            try self.openResultsLog()
        }
    }

    func close() {
        fileHandle?.closeFile()
    }
}
