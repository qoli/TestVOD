//
//  api.swift
//  SyncNext
//
//  Created by 黃佁媛 on 2021/10/13.
//

import Foundation

extension Array where Element == URLQueryItem {
    init<T: LosslessStringConvertible>(_ dictionary: [String: T]) {
        self = dictionary.map({ key, value -> Element in
            URLQueryItem(name: key, value: String(value))
        })
    }
}

@MainActor
class api: NSObject, URLSessionDelegate {
    private var dataString: String?
    private let urlString: String
    private var parameters: [String: String] = [:]

    private var additionalHeadersDict = [
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.14(0x18000e2d) NetType/WIFI Language/zh_HK",
    ]

    private var postData: [String: Any] = [:]

    init(withURLString urlString: String, parameters: [String: String]? = nil, encode: Bool = true) {
        if encode {
            self.urlString = urlString.trimmingCharacters(in: .whitespaces).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
        } else {
            self.urlString = urlString
        }

        self.parameters = parameters ?? [:]
    }

    private var ignoreErrorUI = false
    func setErrorUI(ignore: Bool) {
        ignoreErrorUI = ignore
    }

    func setHeaders(headers: [String: String]) {
        additionalHeadersDict = headers
    }

    func setPostData(with data: [String: Any]) {
        postData = data
    }

    private var isPost: Bool = false
    func setPost() {
        isPost = true
    }

    private var fixUTF8: Bool = false
    func setFixUTF8() {
        fixUTF8 = true
    }

    private var isSSLPinning: Bool = false

    func setSSLPinning(_ bool: Bool) {
        isSSLPinning = bool
    }

    private func buildURL() -> URL? {
        if parameters.isEmpty {
            return URL(string: urlString)
        }

        var com = URLComponents(string: urlString)
        com?.queryItems = .init(parameters)

        return com?.url
    }

    @MainActor private func oldCompletionMethod(completion: @escaping () -> Void) {
        guard var url = buildURL() else {
            completion()
            return
        }

        if fixUTF8 {
            let urlString = url.description.replacingbyRegex(of: "%EF%BF%BC", with: "")
            if let newURL = URL(string: urlString) {
                url = newURL
            }
        }

        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = TimeInterval(5)
        sessionConfiguration.timeoutIntervalForResource = TimeInterval(5)
        sessionConfiguration.httpAdditionalHeaders = additionalHeadersDict

        var session = URLSession(configuration: sessionConfiguration)

        if isSSLPinning {
            print("api isSSLPinning", "...", isSSLPinning)
            session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: OperationQueue.main)
        }

        var request = URLRequest(url: url)

        var thisPost = false

        if !postData.isEmpty || isPost {
            thisPost = true
            do {
                request.httpMethod = "POST"
                request.httpBody = try JSONSerialization.data(withJSONObject: postData, options: [])

            } catch {
                debugPrint(error)
            }
        }

        print("api", !thisPost ? "GET" : "POST", "...", request)

        if request.description.contains("%EF%BF%BC") {
            print("api", "...", "!!! %EF%BF%BC 存在!!!")
        }

        session.dataTask(with: request) { data, _, error in
            if let error = error {
                debugPrint(error)
                DispatchQueue.main.async { [self] in
                    showError(url: url, error: error)
                }
                completion()
            }

            if let data = data {
                DispatchQueue.main.async { [self] in
                    dataString = String(data: data, encoding: .utf8)
                }
                completion()
            }
        }.resume()
    }

    private func asyncTask() async {
        await withUnsafeContinuation { task in
            oldCompletionMethod {
                task.resume()
            }
        }
    }

    func exec() async throws -> String? {
        await asyncTask()
        return dataString
    }

    func showError(url: URL, error: Error) {
        if ignoreErrorUI {
            return
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.host != "prodssl.mddcloud.com.cn" {
            print(#function, "don't need a client certificate")
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // `NSURLAuthenticationMethodClientCertificate`
        // indicates the server requested a client certificate.

        guard
            let file = Bundle.main.url(forResource: "purchase_client", withExtension: "p12"),
            let p12Data = try? Data(contentsOf: file)
        else {
            // Loading of the p12 file's data failed.
            print(#function, "...", "Loading of the p12 file's data failed.")
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Interpret the data in the P12 data blob with
        // a little helper class called `PKCS12`.
        let password = "TvBc@1234" // Obviously this should be stored or entered more securely.
        let p12Contents = PKCS12(pkcs12Data: p12Data, password: password)
        guard let identity = p12Contents.identity else {
            // Creating a PKCS12 never fails, but interpretting th contained data can. So again, no identity? We fall back to default.
            print(#function, "...", "Creating a PKCS12 never fails")
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // In my case, and as Apple recommends,
        // we do not pass the certificate chain into
        // the URLCredential used to respond to the challenge.
        print(#function, "...", "the URLCredential used to respond to the challenge.")
        let credential = URLCredential(identity: identity, certificates: nil, persistence: .none)
        challenge.sender?.use(credential, for: challenge)
        completionHandler(.useCredential, credential)
    }
}

private class PKCS12 {
    let label: String?
    let keyID: NSData?
    let trust: SecTrust?
    let certChain: [SecTrust]?
    let identity: SecIdentity?

    /// Creates a PKCS12 instance from a piece of data.
    /// - Parameters:
    ///   - pkcs12Data: the actual data we want to parse.
    ///   - password: The password required to unlock the PKCS12 data.
    public init(pkcs12Data: Data, password: String) {
        let importPasswordOption: NSDictionary
            = [kSecImportExportPassphrase as NSString: password]
        var items: CFArray?
        let secError: OSStatus
            = SecPKCS12Import(pkcs12Data as NSData,
                              importPasswordOption, &items)
        guard secError == errSecSuccess else {
            if secError == errSecAuthFailed {
                NSLog("Incorrect password?")
            }
            fatalError("Error trying to import PKCS12 data")
        }
        guard let theItemsCFArray = items else { fatalError() }
        let theItemsNSArray: NSArray = theItemsCFArray as NSArray
        guard let dictArray
            = theItemsNSArray as? [[String: AnyObject]] else {
            fatalError()
        }
        func f<T>(key: CFString) -> T? {
            for dict in dictArray {
                if let value = dict[key as String] as? T {
                    return value
                }
            }
            return nil
        }
        label = f(key: kSecImportItemLabel)
        keyID = f(key: kSecImportItemKeyID)
        trust = f(key: kSecImportItemTrust)
        certChain = f(key: kSecImportItemCertChain)
        identity = f(key: kSecImportItemIdentity)
    }
}
