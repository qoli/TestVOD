//
//  String.swift
//  SyncNext
//
//  Created by 黃佁媛 on 2021/10/14.
//

import CryptoKit
import Foundation

extension String {
    var isValidURL: Bool {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        if let match = detector.firstMatch(in: self, options: [], range: NSRange(location: 0, length: utf16.count)) {
            // it is a link, if the match covers the whole string
            return match.range.length == utf16.count
        } else {
            return false
        }
    }

    func md5() -> String {
        return Insecure.MD5.hash(data: data(using: .utf8)!).map { String(format: "%02hhx", $0) }.joined()
    }

    func isValidEmailAddress() -> Bool {
        var returnValue = true
        let emailRegEx = "[A-Z0-9a-z.-_]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,3}"

        do {
            let regex = try NSRegularExpression(pattern: emailRegEx)
            let nsString = self as NSString
            let results = regex.matches(in: self, range: NSRange(location: 0, length: nsString.length))

            if results.count == 0 {
                returnValue = false
            }

        } catch let error as NSError {
            print("invalid regex: \(error.localizedDescription)")
            returnValue = false
        }

        return returnValue
    }

    func regex(for regexPattern: String) -> [[String]] {
        do {
            let text = self
            let regex = try NSRegularExpression(pattern: regexPattern)
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            return matches.map { match in
                (0 ..< match.numberOfRanges).map {
                    let rangeBounds = match.range(at: $0)
                    guard let range = Range(rangeBounds, in: text) else {
                        return ""
                    }
                    return String(text[range])
                }
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }

    func keywordTrim() -> String {
        let str = self

        var range = str.range(of: "(")

        if str.contains("（") {
            range = str.range(of: "（")
        }

        if let sr = range?.lowerBound {
            if String(str[str.startIndex ..< sr]) == "" {
                return str
            } else {
                return String(str[str.startIndex ..< sr])
            }
        } else {
            return str
        }
    }

    func nameRemoveSeason() -> String {
        if let o = regex(for: "第([^\\s*]+)").first?.first {
            return replacingbyRegex(of: o, with: "")
        }

        return self
    }

    func nameGetSeason() -> String? {
        if !contains("第") {
            return nil
        }

        if let o = regex(for: "第([^\\s*]+)季").first?.first {
            return o.regex(for: "[\\d]").joined().joined()
        }

        return nil
    }

    func nameGetEp() -> String? {
        if !contains("第") {
            return nil
        }

        if let o = regex(for: "第([^\\s*]+)集").first?.first {
            return o.regex(for: "[\\d]").joined().joined()
        }

        return nil
    }

    func nameRemoveVideoFormat() -> String {
        return uppercased().replacingOccurrences(of: "720P", with: "").replacingOccurrences(of: "1080P", with: "").replacingOccurrences(of: "4k", with: "").replacingOccurrences(of: "MP4", with: "")
    }

    var lines: [String] {
        return components(separatedBy: "\n")
    }

    public func replacingbyRegex(of pattern: String, with replacement: String, options: NSRegularExpression.Options = []) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(0 ..< utf16.count)
            return regex.stringByReplacingMatches(in: self, options: [],
                                                  range: range, withTemplate: replacement)
        } catch {
            NSLog("replaceAll error: \(error)")
            return self
        }
    }
}

extension String {
    var htmlStripped: String {
        return replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }

    func subtitleTrim() -> String {
        var text = htmlStripped.replacingbyRegex(of: "&lrm;", with: "")
        let reg = text.regex(for: #"position:.* align:.* size:.* line:.*"#).joined().joined()
        text = text.replacingbyRegex(of: reg, with: "")
        let reg2 = text.regex(for: #"line:.*"#).joined().joined()
        text = text.replacingbyRegex(of: reg2, with: "")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var containsChineseCharacters: Bool {
        return range(of: "\\p{Han}", options: .regularExpression) != nil
    }
}

extension String? {
    func UIText(_ text: String) -> String {
        if self == nil {
            return text
        } else {
            return self ?? text
        }
    }
}

extension String {
    func UIText(_ text: String) -> String {
        if self == "" {
            return text
        } else {
            return self
        }
    }
}
