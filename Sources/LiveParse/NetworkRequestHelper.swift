//
//  NetworkRequestHelper.swift
//  LiveParse
//
//  Created by pc on 2025/11/03.
//  Alamofire包装函数，自动捕获请求和响应详情
//

import Foundation
import Alamofire

// MARK: - Alamofire 请求包装器

/// 增强的网络请求助手，自动捕获请求和响应详情
public struct LiveParseRequest {

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
        // 构建请求详情
        let requestDetail = NetworkRequestDetail(
            url: url,
            method: method.rawValue,
            headers: headers?.dictionary,
            parameters: parameters
        )

        logDebug("发起网络请求: \(method.rawValue) \(url)")

        do {
            // 发起请求
            let dataRequest = AF.request(
                url,
                method: method,
                parameters: parameters,
                encoding: encoding,
                headers: headers
            )

            // 获取响应
            let response = await dataRequest.serializingData().response

            // 构建响应详情
            let responseDetail = NetworkResponseDetail(
                statusCode: response.response?.statusCode ?? -1,
                headers: response.response?.headers.dictionary,
                body: response.data.flatMap { String(data: $0, encoding: .utf8) }
            )

            // 检查 HTTP 状态码
            if let statusCode = response.response?.statusCode {
                if statusCode >= 400 {
                    let errorMessage = responseDetail.body ?? "未知错误"
                    logError("服务器返回错误: \(statusCode)")
                    throw LiveParseError.network(.serverError(
                        statusCode: statusCode,
                        message: errorMessage,
                        request: requestDetail,
                        response: responseDetail
                    ))
                }
            }

            // 检查是否有网络错误
            if let error = response.error {
                logError("网络请求失败: \(error.localizedDescription)")

                // 判断错误类型
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

            // 检查是否有响应数据
            guard let data = response.data else {
                logError("响应数据为空")
                throw LiveParseError.network(.invalidResponse(
                    request: requestDetail,
                    response: responseDetail
                ))
            }

            // 尝试解码
            do {
                let decodedData = try decoder.decode(T.self, from: data)
                logDebug("网络请求成功: \(url)")
                return decodedData
            } catch {
                logError("JSON解码失败: \(error.localizedDescription)")
                throw LiveParseError.parse(.decodingFailed(
                    type: String(describing: T.self),
                    location: "\(#file):\(#line)",
                    response: responseDetail,
                    underlyingError: error
                ))
            }

        } catch let error as LiveParseError {
            // 已经是 LiveParseError，直接抛出
            throw error
        } catch {
            // 其他未知错误
            logError("未知错误: \(error.localizedDescription)")
            throw LiveParseError.network(.requestFailed(
                request: requestDetail,
                response: nil,
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
        let requestDetail = NetworkRequestDetail(
            url: url,
            method: method.rawValue,
            headers: headers?.dictionary,
            parameters: parameters
        )

        logDebug("发起网络请求(String): \(method.rawValue) \(url)")

        do {
            let dataRequest = AF.request(
                url,
                method: method,
                parameters: parameters,
                encoding: encoding,
                headers: headers
            )

            let response = await dataRequest.serializingString().response

            let responseDetail = NetworkResponseDetail(
                statusCode: response.response?.statusCode ?? -1,
                headers: response.response?.headers.dictionary,
                body: response.value
            )

            // 检查 HTTP 状态码
            if let statusCode = response.response?.statusCode {
                if statusCode >= 400 {
                    logError("服务器返回错误: \(statusCode)")
                    throw LiveParseError.network(.serverError(
                        statusCode: statusCode,
                        message: response.value ?? "未知错误",
                        request: requestDetail,
                        response: responseDetail
                    ))
                }
            }

            // 检查错误
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

            guard let result = response.value else {
                logError("响应内容为空")
                throw LiveParseError.network(.invalidResponse(
                    request: requestDetail,
                    response: responseDetail
                ))
            }

            logDebug("网络请求成功(String): \(url)")
            return result

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

    /// 执行请求并返回 Data
    public static func requestData(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) async throws -> Data {
        let requestDetail = NetworkRequestDetail(
            url: url,
            method: method.rawValue,
            headers: headers?.dictionary,
            parameters: parameters
        )

        logDebug("发起网络请求(Data): \(method.rawValue) \(url)")

        do {
            let dataRequest = AF.request(
                url,
                method: method,
                parameters: parameters,
                encoding: encoding,
                headers: headers
            )

            let response = await dataRequest.serializingData().response

            let responseDetail = NetworkResponseDetail(
                statusCode: response.response?.statusCode ?? -1,
                headers: response.response?.headers.dictionary,
                body: response.data.flatMap { String(data: $0, encoding: .utf8) }
            )

            if let statusCode = response.response?.statusCode {
                if statusCode >= 400 {
                    logError("服务器返回错误: \(statusCode)")
                    throw LiveParseError.network(.serverError(
                        statusCode: statusCode,
                        message: String(data: response.data ?? Data(), encoding: .utf8) ?? "未知错误",
                        request: requestDetail,
                        response: responseDetail
                    ))
                }
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

            logDebug("网络请求成功(Data): \(url)")
            return data

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
