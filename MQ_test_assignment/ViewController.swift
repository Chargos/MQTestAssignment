////
////  ViewController.swift
////
////  Created by petrovichev maxim on 08.10.2024.
////

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var urlTextField: UITextField!
    @IBOutlet weak var maskTextField: UITextField!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var statusLabel: UILabel!

    private var downloader: Downloader?
    private var parser: Parser?
    private var resultsDataSource: ResultsDataSource?
    private var isDownloading = false
    private var updateTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        statusLabel.text = "Ready for download"
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    @IBAction func startButtonTapped(_ sender: UIButton) {
        guard !isDownloading else {
            return
        }

        startButton.isEnabled = false
        isDownloading = true
        cleanupPreviousRun()

        guard let urlString = urlTextField.text,
              let url = URL(string: urlString),
              let mask = maskTextField.text else {
            self.showErrorAlert(message: "Incorrect URL")
            startButton.isEnabled = true
            isDownloading = false
            return
        }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let resultsFileURL = documentsURL.appendingPathComponent("results.log")
        print(resultsFileURL)
        do {
            resultsDataSource = try ResultsDataSource(resultsFileURL: resultsFileURL)
        } catch {
            self.showErrorAlert(message: error.localizedDescription)
        }
        parser = Parser(maskPattern: mask)
        parser?.delegate = self

        downloader = Downloader()
        downloader?.delegate = self
        downloader?.startDownloading(from: url)

        startUpdateTimer()
    }

    private func cleanupPreviousRun() {
        downloader?.cancel()
        downloader = nil
        parser = nil
        resultsDataSource?.close()
        resultsDataSource = nil
        statusLabel.text = "Ready for download"
        tableView.reloadData()
        stopUpdateTimer()
    }

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(updateTableView), userInfo: nil, repeats: true)
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    @objc private func updateTableView() {
        DispatchQueue.main.async {
            self.resultsDataSource?.loadNextPage { [weak self] in
                guard let self = self else {
                    return
                }
                self.tableView.reloadData()
                if let count = self.resultsDataSource?.displayedLines.count, count > 30 {
                    self.stopUpdateTimer()
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource and UITableViewDelegate

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultsDataSource?.displayedLines.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let line = resultsDataSource?.displayedLines[indexPath.row] else {
            return UITableViewCell()
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = line
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let resultsDataSource = resultsDataSource else { return }

        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height

        if offsetY > contentHeight - frameHeight - 100 {
            resultsDataSource.loadNextPage { [weak self] in
                guard let self = self else {
                    return
                }
                self.tableView.reloadData()
            }
        }
    }
}

// MARK: - DownloaderDelegate

extension ViewController: DownloaderDelegate {
    func downloader(_ downloader: Downloader, didReceiveData data: Data) {
        parser?.process(data: data)
    }

    func downloaderDidFinish(_ downloader: Downloader) {
        parser?.finishProcessing()
    }

    func downloader(_ downloader: Downloader, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.statusLabel.text = "Download error"
            self.startButton.isEnabled = true
            self.isDownloading = false
            self.stopUpdateTimer()
            self.showErrorAlert(message: error.localizedDescription)
        }
    }

    func downloader(_ downloader: Downloader, didUpdateProgress progress: Float) {
        DispatchQueue.main.async {
            self.statusLabel.text = String(format: "Downloaded %.2f%%", progress * 100)
        }
    }
}

// MARK: - ParserDelegate

extension ViewController: ParserDelegate {
    func parser(_ parser: Parser, didMatchLine line: Data) {
        resultsDataSource?.writeLineToLog(line) { [weak self] result in
            if case let .failure(error) = result {
                DispatchQueue.main.async {
                    self?.showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }

    func parserDidFinish(_ parser: Parser) {
        resultsDataSource?.loadNextPage { [weak self] in
            guard let self = self else {
                return
            }
            self.tableView.reloadData()
        }
        DispatchQueue.main.async {
            self.statusLabel.text = "Download completed"
            self.startButton.isEnabled = true
            self.isDownloading = false
            self.stopUpdateTimer()
        }
    }
}

// MARK: - Error Handling

extension ViewController {
    private func showErrorAlert(message: String) {
        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "ОК", style: .default))
        self.present(alertController, animated: true)
    }
}
