//
//  String+Extension.swift
//  testparse
//
//  Created by pc on 2023/12/14.
//

import Foundation
import CommonCrypto

extension String {
    var md5: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    static func stripHTML(from input: String) -> String {
        let pattern = "<[^>]+>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: input.utf16.count)
        return regex?.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: "") ?? input
    }
    
    static func generateRandomString(length: Int) -> String {
        var randomString = ""
        for _ in 0..<length {
            let randomNumber = Int(arc4random_uniform(16))
            let hexString = String(format: "%X", randomNumber)
            randomString += hexString
        }
        return randomString
    }
    func getUrlStringWithShareCode() -> String {
        let urlPattern = "(http|https)://[\\w-]+(\\.[\\w-]+)+([\\w.,@?^=%&:/~+#-]*[\\w@?^=%&/~+#-])?"
        do {
            let regex = try NSRegularExpression(pattern: urlPattern, options: [])
            let nsString = self as NSString
            let results = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
            let urls = results.map { nsString.substring(with: $0.range) }
            return urls.last ?? ""
        } catch {
            return ""
        }
    }
}
