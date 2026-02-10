import Foundation
@preconcurrency import JavaScriptCore

public final class JSRuntime: @unchecked Sendable {
    public typealias LogHandler = @Sendable (String) -> Void

    public static let supportedAPIVersion = 1

    private let queue: DispatchQueue
    private let context: JSContext
    private let session: URLSession

    public init(session: URLSession = .shared, logHandler: LogHandler? = nil) {
        self.queue = DispatchQueue(label: "liveparse.jsruntime.\(UUID().uuidString)")
        self.session = session

        var createdContext: JSContext?
        queue.sync {
            createdContext = JSContext()
        }
        self.context = createdContext!

        queue.sync {
            Self.configureConsole(in: context, logHandler: logHandler)
            Self.configureExceptionHandler(in: context)
            Self.configureHostHTTP(in: context, queue: queue, session: session)
            Self.configureHostCrypto(in: context)
            Self.configureHostHuya(in: context, queue: queue)
            Self.configureHostBootstrap(in: context)
        }
    }

    public func evaluate(script: String, sourceURL: URL? = nil) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                if let sourceURL {
                    self.context.evaluateScript(script, withSourceURL: sourceURL)
                } else {
                    self.context.evaluateScript(script)
                }
                if let exception = self.context.exception {
                    continuation.resume(throwing: LiveParsePluginError.jsException(exception.toString() ?? "<unknown>"))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    public func evaluate(contentsOf url: URL) async throws {
        let script = try String(contentsOf: url, encoding: .utf8)
        try await evaluate(script: script, sourceURL: url)
    }

    public func pluginAPIVersion() async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    guard let pluginObject = self.context.objectForKeyedSubscript("LiveParsePlugin") else {
                        throw LiveParsePluginError.invalidReturnValue("Missing globalThis.LiveParsePlugin")
                    }
                    let apiVersionValue = pluginObject.forProperty("apiVersion")
                    let apiVersion = apiVersionValue?.toInt32() ?? 0
                    continuation.resume(returning: Int(apiVersion))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func callPluginFunction(name: String, payload: [String: Any] = [:]) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    guard let pluginObject = self.context.objectForKeyedSubscript("LiveParsePlugin") else {
                        throw LiveParsePluginError.invalidReturnValue("Missing globalThis.LiveParsePlugin")
                    }
                    guard let fn = pluginObject.objectForKeyedSubscript(name), fn.isObject else {
                        throw LiveParsePluginError.invalidReturnValue("Missing function: \(name)")
                    }

                    let jsPayload = JSValue(object: payload, in: self.context) as Any
                    guard let result = fn.call(withArguments: [jsPayload]) else {
                        if let exception = self.context.exception {
                            throw LiveParsePluginError.jsException(exception.toString() ?? "<unknown>")
                        }
                        throw LiveParsePluginError.invalidReturnValue("Function returned nil")
                    }

                    if Self.isPromise(result) {
                        self.awaitPromise(result, continuation: continuation)
                        return
                    }

                    continuation.resume(returning: try Self.convertToJSONObject(result, in: self.context))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension JSRuntime {
    static func configureConsole(in context: JSContext, logHandler: LogHandler?) {
        let console = JSValue(newObjectIn: context)
        let log: @convention(block) (JSValue) -> Void = { [logHandler] value in
            logHandler?(value.toString() ?? "")
        }
        console?.setObject(log, forKeyedSubscript: "log" as NSString)
        console?.setObject(log, forKeyedSubscript: "error" as NSString)
        context.setObject(console, forKeyedSubscript: "console" as NSString)
    }

    static func configureExceptionHandler(in context: JSContext) {
        context.exceptionHandler = { _, exception in
            _ = exception
        }
    }

    static func configureHostBootstrap(in context: JSContext) {
        // 给插件提供一个稳定的 Host API 表层（底层由 __lp_* 提供）。
        let script = """
        (function () {
          globalThis.Host = globalThis.Host || {};
          Host.http = Host.http || {};
          Host.http.request = function (options) {
            return new Promise(function (resolve, reject) {
              __lp_host_http_request(
                JSON.stringify(options || {}),
                function (resultJSON) { resolve(JSON.parse(resultJSON)); },
                function (err) { reject(err); }
              );
            });
          };

          Host.crypto = Host.crypto || {};
          Host.crypto.md5 = function (input) {
            return __lp_crypto_md5(String(input));
          };
          Host.crypto.base64Decode = function (input) {
            return __lp_crypto_base64_decode(String(input));
          };

          Host.huya = Host.huya || {};
          Host.huya.getCdnTokenInfoEx = function (streamName) {
            return new Promise(function (resolve, reject) {
              __lp_host_huya_get_cdn_token_info_ex(String(streamName), resolve, reject);
            });
          };
        })();
        """
        context.evaluateScript(script)
    }

    static func configureHostHTTP(in context: JSContext, queue: DispatchQueue, session: URLSession) {
        let requestBlock: @convention(block) (String, JSValue, JSValue) -> Void = { optionsJSON, resolve, reject in
            let optionsData = optionsJSON.data(using: .utf8) ?? Data()
            let options = (try? JSONSerialization.jsonObject(with: optionsData) as? [String: Any]) ?? [:]
            guard let urlString = options["url"] as? String, let url = URL(string: urlString) else {
                reject.call(withArguments: ["Invalid url"]) // already on JS thread
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = (options["method"] as? String)?.uppercased() ?? "GET"

            if let timeout = options["timeout"] as? Double {
                request.timeoutInterval = timeout
            }

            if let headers = options["headers"] as? [String: Any] {
                for (k, v) in headers {
                    if let s = v as? String {
                        request.setValue(s, forHTTPHeaderField: k)
                    }
                }
            }

            if let body = options["body"] as? String {
                request.httpBody = body.data(using: .utf8)
            }

            let task = session.dataTask(with: request) { data, response, error in
                queue.async {
                    if let error {
                        reject.call(withArguments: [error.localizedDescription])
                        return
                    }
                    guard let http = response as? HTTPURLResponse else {
                        reject.call(withArguments: ["Invalid response"]) 
                        return
                    }

                    let headersDict: [String: String] = http.allHeaderFields.reduce(into: [:]) { acc, item in
                        if let k = item.key as? String {
                            acc[k] = String(describing: item.value)
                        }
                    }

                    let bodyText = data.flatMap { String(data: $0, encoding: .utf8) }
                    let bodyBase64 = data?.base64EncodedString()

                    let result: [String: Any] = [
                        "status": http.statusCode,
                        "headers": headersDict,
                        "url": http.url?.absoluteString ?? urlString,
                        "bodyText": bodyText as Any,
                        "bodyBase64": bodyBase64 as Any
                    ]

                    let jsonData = (try? JSONSerialization.data(withJSONObject: result)) ?? Data("{}".utf8)
                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                    resolve.call(withArguments: [jsonString])
                }
            }
            task.resume()
        }

        context.setObject(requestBlock, forKeyedSubscript: "__lp_host_http_request" as NSString)
    }

    static func configureHostCrypto(in context: JSContext) {
        let md5Block: @convention(block) (String) -> String = { input in
            input.md5
        }
        let base64DecodeBlock: @convention(block) (String) -> String = { input in
            guard let decoded = input.removingPercentEncoding,
                  let data = Data(base64Encoded: decoded),
                  let str = String(data: data, encoding: .utf8)
            else {
                return ""
            }
            return str
        }
        context.setObject(md5Block, forKeyedSubscript: "__lp_crypto_md5" as NSString)
        context.setObject(base64DecodeBlock, forKeyedSubscript: "__lp_crypto_base64_decode" as NSString)
    }

    static func configureHostHuya(in context: JSContext, queue: DispatchQueue) {
        let tokenBlock: @convention(block) (String, JSValue, JSValue) -> Void = { streamName, resolve, reject in
            Task {
                do {
                    let token = try await Huya.plugin_getCdnTokenInfoEx(streamName: streamName)
                    queue.async {
                        resolve.call(withArguments: [token])
                    }
                } catch {
                    queue.async {
                        reject.call(withArguments: [String(describing: error)])
                    }
                }
            }
        }
        context.setObject(tokenBlock, forKeyedSubscript: "__lp_host_huya_get_cdn_token_info_ex" as NSString)
    }

    static func isPromise(_ value: JSValue) -> Bool {
        guard value.isObject else { return false }
        let then = value.forProperty("then")
        return then?.isObject == true
    }

    func awaitPromise(_ promise: JSValue, continuation: CheckedContinuation<Any, Error>) {
        let resolve: @convention(block) (JSValue) -> Void = { value in
            do {
                continuation.resume(returning: try Self.convertToJSONObject(value, in: self.context))
            } catch {
                continuation.resume(throwing: error)
            }
        }
        let reject: @convention(block) (JSValue) -> Void = { value in
            continuation.resume(throwing: LiveParsePluginError.jsException(value.toString() ?? "<unknown>"))
        }
        promise.invokeMethod("then", withArguments: [resolve, reject])
    }

    static func convertToJSONObject(_ value: JSValue, in context: JSContext) throws -> Any {
        if value.isUndefined || value.isNull {
            return NSNull()
        }

        let json = context.objectForKeyedSubscript("JSON")
        guard let jsonStringValue = json?.invokeMethod("stringify", withArguments: [value]),
              let jsonString = jsonStringValue.toString()
        else {
            throw LiveParsePluginError.invalidReturnValue("JSON.stringify failed")
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw LiveParsePluginError.invalidReturnValue("Invalid UTF-8 JSON")
        }
        return try JSONSerialization.jsonObject(with: data)
    }
}
