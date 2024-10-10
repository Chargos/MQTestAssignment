//
//  Downloader.swift
//
//  Created by petrovichev maxim on 08.10.2024.
//

import Foundation

protocol DownloaderDelegate: AnyObject {
    func downloader(_ downloader: Downloader, didReceiveData data: Data)
    func downloaderDidFinish(_ downloader: Downloader)
    func downloader(_ downloader: Downloader, didFailWithError error: Error)
    func downloader(_ downloader: Downloader, didUpdateProgress progress: Float)
}

class Downloader: NSObject, URLSessionDataDelegate {
    private var urlSession: URLSession!
    private var dataTask: URLSessionDataTask?
    private var expectedContentLength: Int64 = 0
    private var totalBytesReceived: Int64 = 0

    weak var delegate: DownloaderDelegate?

    func startDownloading(from url: URL) {
        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        dataTask = urlSession.dataTask(with: url)
        dataTask?.resume()
    }

    func cancel() {
        dataTask?.cancel()
        urlSession.invalidateAndCancel()
        dataTask = nil
        urlSession = nil
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        totalBytesReceived += Int64(data.count)
        let progress = expectedContentLength > 0 ? Float(totalBytesReceived) / Float(expectedContentLength) : 0
        delegate?.downloader(self, didUpdateProgress: progress)
        delegate?.downloader(self, didReceiveData: data)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        expectedContentLength = response.expectedContentLength
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            delegate?.downloader(self, didFailWithError: error)
        } else {
            delegate?.downloaderDidFinish(self)
        }
    }
}
