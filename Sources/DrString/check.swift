import Crawler
import Critic
import Informant
import IsTTY

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Dispatch

public let checkCommand = Command(
    name: "check",
    shortDescription: "Check problems for existing doc strings")
{ config, _ in
    var startTime = getTime()
    var problemCount = 0
    var fileCount = 0
    let ignoreThrows = config.options.ignoreDocstringForThrows
    let format = config.options.outputFormat
    let firstLetterUpper: Bool?

    switch config.options.firstKeywordLetter {
    case .lowercase:
        firstLetterUpper = false
    case .uppercase:
        firstLetterUpper = true
    case .whatever:
        firstLetterUpper = nil
    }

    let group = DispatchGroup()
    let queue = DispatchQueue.global()
    for path in config.paths {
        group.enter()
        queue.async {
            do {
                for documentable in try extractDocs(fromSourcePath: path).compactMap({ $0 }) {
                    if let problem = try validate(documentable, ignoreThrows: ignoreThrows, firstLetterUpper: firstLetterUpper, needsSeparation: config.options.separatedSections) {
                        problemCount += problem.details.count
                        let output: String
                        switch (format, IsTerminal.standardOutput) {
                        case (.automatic, true), (.terminal, _):
                            output = ttyText(for: problem)
                        case (.automatic, false), (.plain, _):
                            output = plainText(for: problem)
                        }

                        print("\(output)\n")
                    }
                }
            } catch let error {}
            group.leave()
        }
        fileCount += 1
    }

    group.wait()
    let elapsedTime = readableDiff(from: startTime, to: getTime())

    if problemCount > 0 {
        let summary: String
        if IsTerminal.standardError {
            summary = "Found \(String(problemCount), color: .red) problem\(problemCount > 1 ? "s" : "") in \(String(fileCount), color: .blue) file\(fileCount > 1 ? "s" : "") in \(elapsedTime, color: .blue)\n"
        } else {
            summary = "Found \(problemCount) problem\(problemCount > 1 ? "s" : "") in \(fileCount) file\(problemCount > 1 ? "s" : "") in \(elapsedTime)\n"
        }

        fputs(summary, stderr)
        return 1
    } else {
        return nil
    }
}
