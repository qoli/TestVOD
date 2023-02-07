//
//  URL.swift
//  SyncNext
//
//  Created by 黃佁媛 on 2021/11/2.
//

import Foundation

protocol URLQueryParameterStringConvertible {
    var queryParameters: String { get }
}

extension Dictionary: URLQueryParameterStringConvertible {
    /**
      This computed property returns a query parameters string from the given NSDictionary. For
      example, if the input is @{@"day":@"Tuesday", @"month":@"January"}, the output
      string will be @"day=Tuesday&month=January".
      @return The computed parameters string.
     */
    var queryParameters: String {
        var parts: [String] = []
        for (key, value) in self {
            let part = String(format: "%@=%@",
                              String(describing: key).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!,
                              String(describing: value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
            parts.append(part as String)
        }
        return parts.joined(separator: "&")
    }
}

extension URL {
    /**
      Creates a new URL by adding the given query parameters.
      @param parametersDictionary The query parameter dictionary to add.
      @return A new URL.
     */
    func appendingQueryParameters(_ parametersDictionary: Dictionary<String, String>) -> URL {
        let URLString: String = String(format: "%@?%@", absoluteString, parametersDictionary.queryParameters)
        return URL(string: URLString)!
    }
}

extension URL {
    func queryOf(_ queryParameterName: String) -> String? {
        guard let url = URLComponents(string: absoluteString) else { return nil }
        return url.queryItems?.first(where: { $0.name == queryParameterName })?.value
    }
}

extension URL {
    /** Request the http status of the URL resource by sending a "HEAD" request over the network. A nil response means an error occurred. */
    public func requestHTTPStatus(completion: @escaping (_ status: Int?) -> Void) {
        // Adapted from https://stackoverflow.com/a/35720670/7488171
        var request = URLRequest(url: self)
        request.httpMethod = "HEAD"
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse, error == nil {
                completion(httpResponse.statusCode)
            } else {
                completion(nil)
            }
        }
        task.resume()
    }

    /** Measure the response time in seconds of an http "HEAD" request to the URL resource. A nil response means an error occurred. */
    public func responseTime(completion: @escaping (TimeInterval?) -> Void) {
        let startTime = DispatchTime.now().uptimeNanoseconds
        requestHTTPStatus { status in
            if status != nil {
                let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - startTime
                completion(TimeInterval(elapsedNanoseconds) / 1e9)
            } else {
                completion(nil)
            }
        }
    }

    public func responseTimeAsync() async -> TimeInterval? {
        let time = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.responseTime { time in
                    continuation.resume(returning: time)
                }
            }
        }

        return time
    }
}
