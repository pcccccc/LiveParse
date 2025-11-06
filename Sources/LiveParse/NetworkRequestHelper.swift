//
//  NetworkRequestHelper.swift
//  LiveParse
//
//  Created by pc on 2025/11/03.
//  Alamofire包装函数，自动捕获请求和响应详情
//

import Foundation
import Alamofire

// MARK: - 原始响应封装

/// 包含原始数据和响应详情的请求结果
public struct NetworkRawResponse {
    public let data: Data
    public let request: NetworkRequestDetail
    public let response: NetworkResponseDetail
    public let httpURLResponse: HTTPURLResponse?

    public init(
        data: Data,
        request: NetworkRequestDetail,
        response: NetworkResponseDetail,
        httpURLResponse: HTTPURLResponse?
    ) {
        self.data = data
        self.request = request
        self.response = response
        self.httpURLResponse = httpURLResponse
    }

    /// 最终的请求 URL（考虑重定向）
    public var finalURL: String? {
        return httpURLResponse?.url?.absoluteString
    }
}

// MARK: - Alamofire 请求包装器

/// 增强的网络请求助手，自动捕获请求和响应详情
public struct LiveParseRequest {

    /// 执行请求并返回原始数据和响应详情
    @discardableResult
    public static func requestRaw(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) async throws -> NetworkRawResponse {
        let requestDetail = NetworkRequestDetail(
            url: url,
            method: method.rawValue,
            headers: headers?.dictionary,
            parameters: parameters
        )

        logDebug("发起网络请求(Raw): \(method.rawValue) \(url)")

        do {
            let dataRequest = AF.request(
                url,
                method: method,
                parameters: parameters,
                encoding: encoding,
                headers: headers
            )

            let response = await dataRequest.serializingData().response

            let responseBody = response.data.flatMap { String(data: $0, encoding: .utf8) }

            let responseDetail = NetworkResponseDetail(
                statusCode: response.response?.statusCode ?? -1,
                headers: response.response?.headers.dictionary,
                body: responseBody
            )

            if let statusCode = response.response?.statusCode, statusCode >= 400 {
                let errorMessage = responseBody ?? "未知错误"
                logError("服务器返回错误: \(statusCode)")
                throw LiveParseError.network(.serverError(
                    statusCode: statusCode,
                    message: errorMessage,
                    request: requestDetail,
                    response: responseDetail
                ))
            }

            if let error = response.error {
                logError("网络请求失败: \(error.localizedDescription)")

                if error.isTimeout {
                    throw LiveParseError.network(.timeout(request: requestDetail))
                } else if error.isSessionTaskError {
                    throw LiveParseError.network(.noConnection)
                } else {
                    throw LiveParseError.network(.requestFailed(
                        request: requestDetail,
                        response: responseDetail,
                        underlyingError: error
                    ))
                }
            }

            guard let data = response.data else {
                logError("响应数据为空")
                throw LiveParseError.network(.invalidResponse(
                    request: requestDetail,
                    response: responseDetail
                ))
            }

            return NetworkRawResponse(
                data: data,
                request: requestDetail,
                response: responseDetail,
                httpURLResponse: response.response
            )

        } catch let error as LiveParseError {
            throw error
        } catch {
            logError("未知错误: \(error.localizedDescription)")
            throw LiveParseError.network(.requestFailed(
                request: requestDetail,
                response: nil,
                underlyingError: error
            ))
        }
    }

    /// 执行 GET 请求并自动捕获详细信息
    public static func get<T: Decodable>(
        _ url: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        return try await request(
            url,
            method: .get,
            parameters: parameters,
            headers: headers,
            decoder: decoder
        )
    }

    /// 执行 POST 请求并自动捕获详细信息
    public static func post<T: Decodable>(
        _ url: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        return try await request(
            url,
            method: .post,
            parameters: parameters,
            headers: headers,
            decoder: decoder
        )
    }

    /// 通用请求方法，自动捕获详细信息
    public static func request<T: Decodable>(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let rawResponse = try await requestRaw(
            url,
            method: method,
            parameters: parameters,
            encoding: encoding,
            headers: headers
        )

        do {
            let decodedData = try decoder.decode(T.self, from: rawResponse.data)
            logDebug("网络请求成功: \(url)")
            return decodedData
        } catch {
            logError("JSON解码失败: \(error.localizedDescription)")
            throw LiveParseError.parse(.decodingFailed(
                type: String(describing: T.self),
                location: "\(#file):\(#line)",
                response: rawResponse.response,
                underlyingError: error
            ))
        }
    }

    /// 执行请求并返回字符串（用于需要手动解析的情况）
    public static func requestString(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) async throws -> String {
        let rawResponse = try await requestRaw(
            url,
            method: method,
            parameters: parameters,
            encoding: encoding,
            headers: headers
        )

        if let body = rawResponse.response.body ?? String(data: rawResponse.data, encoding: .utf8) {
            logDebug("网络请求成功(String): \(url)")
            return body
        }

        logError("响应内容为空")
        throw LiveParseError.network(.invalidResponse(
            request: rawResponse.request,
            response: rawResponse.response
        ))
    }

    /// 执行请求并返回 Data
    public static func requestData(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) async throws -> Data {
        let rawResponse = try await requestRaw(
            url,
            method: method,
            parameters: parameters,
            encoding: encoding,
            headers: headers
        )

        logDebug("网络请求成功(Data): \(url)")
        return rawResponse.data
    }
}

// MARK: - AFError 扩展

extension AFError {
    /// 是否是超时错误
    var isTimeout: Bool {
        if case .sessionTaskFailed(let error) = self {
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut
        }
        return false
    }

    /// 是否是会话任务错误（通常表示无网络连接）
    var isSessionTaskError: Bool {
        if case .sessionTaskFailed = self {
            return true
        }
        return false
    }
}
