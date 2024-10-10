# Test Assignment for iOS Developer

## Overview

This assignment is to develop an iOS application that downloads, processes, and displays text from a file located at a URL. The app filters lines based on a user-specified pattern and shows them in a list.

## Requirements

### Platform

- **Minimum iOS version:** 11.0
- **Language:** Objective-C or Swift (developer’s choice)

### Application Flow

1. The user inputs a URL pointing to a text file.
2. The user specifies a pattern filter for selecting lines.
3. The user initiates the download process (e.g., by pressing a button).
4. The application downloads the file and filters the lines based on the provided pattern.
5. The filtered lines are displayed in a list (UITableView or UICollectionView).

### Line Filtering Logic

- The input text file is assumed to be an ANSI text file (no need to support UTF-8).
- The filtering logic uses a simple pattern-matching system, similar to regular expressions, supporting at least the following operators:
  - `*` matches a sequence of any characters of unlimited length.
  - `?` matches any single character.
- Examples of valid patterns:
  - `*abc*` matches all lines containing "abc" with any sequence of characters before or after it.
  - `abc*` matches all lines starting with "abc" followed by any sequence of characters.
  - `abc?` matches all lines starting with "abc" followed by exactly one additional character.
  - `abc` matches all lines that exactly equal "abc".
  - Patterns such as `*Some*`, `*Some`, `Some*`, and `*****Some***` should be handled correctly without restrictions on the position of `*` in the pattern.

### Additional Requirements

- **File Size:** The input text file may be very large (up to hundreds of megabytes). Memory consumption should be optimized.
- **Text Processing:** Should be done incrementally as each portion of the file is downloaded. Avoid downloading the entire file at once.
- **Results File:** The filtered lines should be written to a file named `results.log` in the application's directory.
- **UI:** Display the filtered results in a list using either `UITableView` or `UICollectionView`.
- **Robustness:** The code should handle errors gracefully and be resistant to crashes or unexpected behavior.

## Formatting and Code Quality

- The code should be clean, simple, and easy to understand.
- Aim for a neat, maintainable structure with well-organized methods and classes.
- Ensure proper error handling and fail-safes where appropriate.

## Submission

- Submit a fully working iOS project in a ZIP archive.
- The project should be ready to build and run in Xcode.
