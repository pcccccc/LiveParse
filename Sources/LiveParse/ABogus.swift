import Foundation
import GMObjC

public struct StringProcessor {
    public static func toOrdStr(_ s: [UInt8]) -> String {
        return String(bytes: s, encoding: .isoLatin1) ?? ""
    }

    public static func toOrdArray(_ s: String) -> [UInt8] {
        return Array(s.utf8)
    }

    public static func toCharStr(_ s: [UInt8]) -> String {
        // 对应Python的 "".join([chr(i) for i in s])
        // 直接创建Unicode字符，支持任何值
        return s.map {
            String(Character(UnicodeScalar($0) ?? UnicodeScalar(0)!))
        }.joined()
    }

    public static func toCharArray(_ s: String) -> [UInt8] {
        return Array(s.utf8)
    }

    public static func jsShiftRight(_ val: UInt64, _ n: Int) -> UInt64 {
        return (val % 0x100000000) >> n
    }

    public static func generateRandomBytes(length: Int = 3) -> String {
        func generateByteSequence() -> [Character] {
            let rd = UInt64.random(in: 0..<10000)
            return [
                Character(UnicodeScalar(Int(((rd & 255) & 170) | 1))!),
                Character(UnicodeScalar(Int(((rd & 255) & 85) | 2))!),
                Character(UnicodeScalar(Int((jsShiftRight(rd, 8) & 170) | 5))!),
                Character(UnicodeScalar(Int((jsShiftRight(rd, 8) & 85) | 40))!)
            ]
        }

        var result: [Character] = []
        for _ in 0..<length {
            result.append(contentsOf: generateByteSequence())
        }

        return String(result)
    }
}


public class CryptoUtility {
    public let salt: String
    public let base64Alphabet: [String]
    public var bigArray: [UInt8]

    public init(salt: String, customBase64Alphabet: [String]) {
        self.salt = salt
        self.base64Alphabet = customBase64Alphabet
        self.bigArray = [
            121, 243,  55, 234, 103,  36,  47, 228,  30, 231, 106,   6, 115,  95,  78, 101, 250, 207, 198,  50,
            139, 227, 220, 105,  97, 143,  34,  28, 194, 215,  18, 100, 159, 160,  43,   8, 169, 217, 180, 120,
            247,  45,  90,  11,  27, 197,  46,   3,  84,  72,   5,  68,  62,  56, 221,  75, 144,  79,  73, 161,
            178,  81,  64, 187, 134, 117, 186, 118,  16, 241, 130,  71,  89, 147, 122, 129,  65,  40,  88, 150,
            110, 219, 199, 255, 181, 254,  48,   4, 195, 248, 208,  32, 116, 167,  69, 201,  17, 124, 125, 104,
             96,  83,  80, 127, 236, 108, 154, 126, 204,  15,  20, 135, 112, 158,  13,   1, 188, 164, 210, 237,
            222,  98, 212,  77, 253,  42, 170, 202,  26,  22,  29, 182, 251,  10, 173, 152,  58, 138,  54, 141,
            185,  33, 157,  31, 252, 132, 233, 235, 102, 196, 191, 223, 240, 148,  39, 123,  92,  82, 128, 109,
             57,  24,  38, 113, 209, 245,   2, 119, 153, 229, 189, 214, 230, 174, 232,  63,  52, 205,  86, 140,
             66, 175, 111, 171, 246, 133, 238, 193,  99,  60,  74,  91, 225,  51,  76,  37, 145, 211, 166, 151,
            213, 206,   0, 200, 244, 176, 218,  44, 184, 172,  49, 216,  93, 168,  53,  21, 183,  41,  67,  85,
            224, 155, 226, 242,  87, 177, 146,  70, 190,  12, 162,  19, 137, 114,  25, 165, 163, 192,  23,  59,
              9,  94, 179, 107,  35,   7, 142, 131, 239, 203, 149, 136,  61, 249,  14, 156
        ]
    }

    public static func sm3ToArray(inputData: Any) -> [UInt8] {
        let inputString: String

        if let stringData = inputData as? String {
            inputString = stringData
            //这句可能有把字符串变成小写
            let hexString = GMSm3Utils.hash(withText: inputString) ?? ""
            var result: [UInt8] = []
            for i in stride(from: 0, to: hexString.count, by: 2) {
                let startIndex = hexString.index(hexString.startIndex, offsetBy: i)
                let endIndex = hexString.index(startIndex, offsetBy: 2)
                let hexByte = String(hexString[startIndex..<endIndex])
                if let byte = UInt8(hexByte, radix: 16) {
                    result.append(byte)
                }
            }
            return result
        } else if let arrayData = inputData as? [UInt8] {
            // 对应Python的 bytes(input_data) + func.bytes_to_list() + sm3.sm3_hash()
            let inputBytes = Data(arrayData)

            // 使用GMSm3Utils进行哈希，它应该自动处理SM3的填充
            let hashData = GMSm3Utils.hash(with: inputBytes) ?? Data()
            // 将哈希结果转换为十六进制字符串
            let hexString = hashData.map { String(format: "%02x", $0) }.joined()
            var result: [UInt8] = []
            for i in stride(from: 0, to: hexString.count, by: 2) {
                let startIndex = hexString.index(hexString.startIndex, offsetBy: i)
                let endIndex = hexString.index(startIndex, offsetBy: 2)
                let hexByte = String(hexString[startIndex..<endIndex])
                if let byte = UInt8(hexByte, radix: 16) {
                    result.append(byte)
                }
            }
            return result
        } else {
            inputString = ""
            return []
        }
    }

    public func addSalt(_ param: String) -> String {
        return param + salt
    }

    public func processParam(_ param: Any, addSalt: Bool) -> Any {
        if let stringParam = param as? String, addSalt {
            return self.addSalt(stringParam)
        }
        return param
    }

    public func paramsToArray(_ param: Any, addSalt: Bool = true) -> [UInt8] {
        let processedParam = processParam(param, addSalt: addSalt)
        return CryptoUtility.sm3ToArray(inputData: processedParam)
    }

    public var rawTransformValues: [Int] = []  // 存储原始整数值

    public func transformBytes(_ bytesList: [Int]) -> String {
        let bytesStr = bytesList.map {
            String(Character(UnicodeScalar($0) ?? UnicodeScalar(0)!))
        }.joined()

        var resultValues: [Int] = []
        var indexB = Int(bigArray[1])
        var initialValue = 0
        var valueE = 0

        for (index, char) in bytesStr.enumerated() {
            var sumInitial: Int
            if index == 0 {
                initialValue = Int(bigArray[indexB])
                sumInitial = indexB + initialValue

                bigArray[1] = UInt8(initialValue)
                bigArray[indexB] = UInt8(indexB)
            } else {
                sumInitial = initialValue + valueE
            }

            let charValue = Int(char.unicodeScalars.first?.value ?? 0)
            sumInitial %= bigArray.count
            let valueF = Int(bigArray[sumInitial])
            let encryptedChar = charValue ^ valueF

            resultValues.append(encryptedChar)

            valueE = Int(bigArray[(index + 2) % bigArray.count])
            sumInitial = (indexB + valueE) % bigArray.count
            initialValue = Int(bigArray[sumInitial])
            bigArray[sumInitial] = bigArray[(index + 2) % bigArray.count]
            bigArray[(index + 2) % bigArray.count] = UInt8(initialValue)
            indexB = sumInitial
        }

        rawTransformValues = resultValues
        let result = String(repeating: "X", count: resultValues.count)

        return result
    }

    public func base64Encode(_ inputString: String, selectedAlphabet: Int = 0) -> String {
        // 直接获取字符的Unicode值，对应Python的ord(char)
        let charValues = inputString.map { Int($0.unicodeScalars.first?.value ?? 0) }
        let binaryString = charValues.map { String($0, radix: 2).padded(toLength: 8, withPad: "0", startingAt: 0) }
            .joined()

        let paddingLength = (6 - binaryString.count % 6) % 6
        let paddedBinaryString = binaryString + String(repeating: "0", count: paddingLength)

        let base64Indices = stride(from: 0, to: paddedBinaryString.count, by: 6)
            .map { index in
                let endIndex = paddedBinaryString.index(paddedBinaryString.startIndex, offsetBy: min(index + 6, paddedBinaryString.count))
                let substring = String(paddedBinaryString[paddedBinaryString.index(paddedBinaryString.startIndex, offsetBy: index)..<endIndex])
                return Int(substring, radix: 2) ?? 0
            }

        let alphabet = base64Alphabet[selectedAlphabet]
        let outputString = base64Indices.map { String(alphabet[alphabet.index(alphabet.startIndex, offsetBy: $0)]) }.joined()

        return outputString + String(repeating: "=", count: paddingLength / 2)
    }

    public func abogusEncode(_ abogusBytesStr: String, selectedAlphabet: Int) -> String {
        var abogus: [String] = []
        let alphabet = base64Alphabet[selectedAlphabet]

        // 构建完整的Unicode值数组：random + transform
        let randomValues = StringProcessor.generateRandomBytes().map { Int($0.unicodeScalars.first?.value ?? 0) }
        let charValues = randomValues + rawTransformValues

        for i in stride(from: 0, to: charValues.count, by: 3) {
            let n: UInt32

            if i + 2 < charValues.count {
                let char1 = UInt32(charValues[i])
                let char2 = UInt32(charValues[i + 1])
                let char3 = UInt32(charValues[i + 2])
                n = (char1 << 16) | (char2 << 8) | char3
            } else if i + 1 < charValues.count {
                let char1 = UInt32(charValues[i])
                let char2 = UInt32(charValues[i + 1])
                n = (char1 << 16) | (char2 << 8)
            } else {
                let char1 = UInt32(charValues[i])
                n = char1 << 16
            }

            let shifts = [18, 12, 6, 0]
            let masks: [UInt32] = [0xFC0000, 0x03F000, 0x0FC0, 0x3F]

            for (j, (shift, mask)) in zip(shifts, masks).enumerated() {
                if shift == 6 && i + 1 >= charValues.count {
                    break
                }
                if shift == 0 && i + 2 >= charValues.count {
                    break
                }
                let index = Int((n & mask) >> shift)
                abogus.append(String(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)]))
            }
        }

        let padding = String(repeating: "=", count: (4 - abogus.count % 4) % 4)
        abogus.append(padding)
        return abogus.joined()
    }

    public static func rc4Encrypt(key: Data, plaintext: String) -> Data {
        var S = Array(0..<256)
        var j = 0

        for i in 0..<256 {
            j = (j + S[i] + Int(key[i % key.count])) % 256
            S.swapAt(i, j)
        }

        var i = 0
        j = 0
        var ciphertext: [UInt8] = []

        for char in plaintext {
            i = (i + 1) % 256
            j = (j + S[i]) % 256
            S.swapAt(i, j)
            let K = S[(S[i] + S[j]) % 256]
            ciphertext.append(UInt8(char.asciiValue ?? 0) ^ UInt8(K))
        }

        return Data(ciphertext)
    }
}

public extension String {
    public func padded(toLength length: Int, withPad pad: String, startingAt index: Int) -> String {
        if self.count >= length {
            return self
        }
        let padding = String(repeating: pad, count: length - self.count)
        return padding + self
    }
}

public class BrowserFingerprintGenerator {
    private static let browsers: [String: () -> String] = [
        "Chrome": generateChromeFingerprint,
        "Firefox": generateFirefoxFingerprint,
        "Safari": generateSafariFingerprint,
        "Edge": generateEdgeFingerprint
    ]

    public static func generateFingerprint(browserType: String = "Edge") -> String {
        return browsers[browserType, default: generateEdgeFingerprint]()
    }

    public static func generateChromeFingerprint() -> String {
        return _generateFingerprint(platform: "Win32")
    }

    public static func generateFirefoxFingerprint() -> String {
        return _generateFingerprint(platform: "Win32")
    }

    public static func generateSafariFingerprint() -> String {
        return _generateFingerprint(platform: "MacIntel")
    }

    public static func generateEdgeFingerprint() -> String {
        return _generateFingerprint(platform: "Win32")
    }

    private static func _generateFingerprint(platform: String) -> String {
        let innerWidth = Int.random(in: 1024...1920)
        let innerHeight = Int.random(in: 768...1080)
        let outerWidth = innerWidth + Int.random(in: 24...32)
        let outerHeight = innerHeight + Int.random(in: 75...90)
        let screenX = 0
        let screenY = [0, 30].randomElement()!
        let sizeWidth = Int.random(in: 1024...1920)
        let sizeHeight = Int.random(in: 768...1080)
        let availWidth = Int.random(in: 1280...1920)
        let availHeight = Int.random(in: 800...1080)

        return "\(innerWidth)|\(innerHeight)|\(outerWidth)|\(outerHeight)|\(screenX)|\(screenY)|0|0|\(sizeWidth)|\(sizeHeight)|\(availWidth)|\(availHeight)|\(innerWidth)|\(innerHeight)|24|24|\(platform)"
    }
}

public class ABogus {
    public let aid: Int
    public let pageId: Int
    public let salt: String
    public let boe: Bool
    public let ddrt: Double
    public let ic: Double
    public let paths: [String]
    public var array1: [UInt8] = []
    public var array2: [UInt8] = []
    public var array3: [UInt8] = []
    public let options: [Int]
    public let uaKey: Data
    public let character: String
    public let character2: String
    public let characterList: [String]
    public let cryptoUtility: CryptoUtility
    public let userAgent: String
    public let browserFp: String
    public let sortIndex: [Int]
    public let sortIndex2: [Int]

    public init(fp: String = "", userAgent: String = "", options: [Int] = [0, 1, 14]) {
        self.aid = 6383
        self.pageId = 0
        self.salt = "cus"
        self.boe = false
        self.ddrt = 8.5
        self.ic = 8.5
        self.paths = [
            "^/webcast/",
            "^/aweme/v1/",
            "^/aweme/v2/",
            "/v1/message/send",
            "^/live/",
            "^/captcha/",
            "^/ecom/"
        ]
        self.options = options
        self.uaKey = Data([0x00, 0x01, 0x0E])

        self.character = "Dkdpgh2ZmsQB80/MfvV36XI1R45-WUAlEixNLwoqYTOPuzKFjJnry79HbGcaStCe"
        self.character2 = "ckdp1h4ZKsUB80/Mfvw36XIgR25+WQAlEi7NLboqYTOPuzmFjJnryx9HVGDaStCe"
        self.characterList = [character, character2]

        self.cryptoUtility = CryptoUtility(salt: salt, customBase64Alphabet: characterList)

        self.userAgent = !userAgent.isEmpty ? userAgent : "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0"

        self.browserFp = !fp.isEmpty ? fp : BrowserFingerprintGenerator.generateFingerprint(browserType: "Edge")

        self.sortIndex = [
            18, 20, 52, 26, 30, 34, 58, 38, 40, 53, 42, 21, 27, 54, 55, 31, 35, 57, 39, 41, 43, 22, 28,
            32, 60, 36, 23, 29, 33, 37, 44, 45, 59, 46, 47, 48, 49, 50, 24, 25, 65, 66, 70, 71
        ]
        self.sortIndex2 = [
            18, 20, 26, 30, 34, 38, 40, 42, 21, 27, 31, 35, 39, 41, 43, 22, 28, 32, 36, 23, 29, 33, 37,
            44, 45, 46, 47, 48, 49, 50, 24, 25, 52, 53, 54, 55, 57, 58, 59, 60, 65, 66, 70, 71
        ]
    }

    public func encodeData(_ data: String, alphabetIndex: Int = 0) -> String {
        return cryptoUtility.abogusEncode(data, selectedAlphabet: alphabetIndex)
    }

    public func generateAbogus(params: String, body: String = "") -> (String, String, String, String) {
        var abDir: [Int: Any] = [
            8: 3,
            15: [
                "aid": aid,
                "pageId": pageId,
                "boe": boe,
                "ddrt": ddrt,
                "paths": paths,
                "track": ["mode": 0, "delay": 300, "paths": []],
                "dump": true,
                "rpU": ""
            ] as [String: Any],
            18: 44,
            19: [1, 0, 1, 0, 1],
            66: 0,
            69: 0,
            70: 0,
            71: 0
        ]
        let startEncryption = Int(Date().timeIntervalSince1970 * 1000)
        let array0 = cryptoUtility.paramsToArray(params)
        let array1 = cryptoUtility.paramsToArray(array0)
        let array2 = cryptoUtility.paramsToArray(cryptoUtility.paramsToArray(body))

        let encryptedUA = CryptoUtility.rc4Encrypt(key: uaKey, plaintext: userAgent)
        let encryptedArray = Array(encryptedUA)
        let ord = StringProcessor.toOrdStr(encryptedArray)

        let base64EncodedUA = cryptoUtility.base64Encode(ord, selectedAlphabet: 1)
        let array3 = cryptoUtility.paramsToArray(base64EncodedUA, addSalt: false)

        let endEncryption = Int(Date().timeIntervalSince1970 * 1000)

        abDir[20] = (startEncryption >> 24) & 255
        abDir[21] = (startEncryption >> 16) & 255
        abDir[22] = (startEncryption >> 8) & 255
        abDir[23] = startEncryption & 255
        abDir[24] = startEncryption / 256 / 256 / 256 / 256
        abDir[25] = startEncryption / 256 / 256 / 256 / 256 / 256

        abDir[26] = (options[0] >> 24) & 255
        abDir[27] = (options[0] >> 16) & 255
        abDir[28] = (options[0] >> 8) & 255
        abDir[29] = options[0] & 255

        abDir[30] = (options[1] / 256) & 255
        abDir[31] = (options[1] % 256) & 255
        abDir[32] = (options[1] >> 24) & 255
        abDir[33] = (options[1] >> 16) & 255

        abDir[34] = (options[2] >> 24) & 255
        abDir[35] = (options[2] >> 16) & 255
        abDir[36] = (options[2] >> 8) & 255
        abDir[37] = options[2] & 255

        abDir[38] = Int(array1[21])
        abDir[39] = Int(array1[22])
        abDir[40] = Int(array2[21])
        abDir[41] = Int(array2[22])
        abDir[42] = Int(array3[23])
        abDir[43] = Int(array3[24])

        abDir[44] = (endEncryption >> 24) & 255
        abDir[45] = (endEncryption >> 16) & 255
        abDir[46] = (endEncryption >> 8) & 255
        abDir[47] = endEncryption & 255
        abDir[48] = abDir[8] as! Int
        abDir[49] = endEncryption / 256 / 256 / 256 / 256
        abDir[50] = endEncryption / 256 / 256 / 256 / 256 / 256

        abDir[51] = (pageId >> 24) & 255
        abDir[52] = (pageId >> 16) & 255
        abDir[53] = (pageId >> 8) & 255
        abDir[54] = pageId & 255
        abDir[55] = pageId
        abDir[56] = aid
        abDir[57] = aid & 255
        abDir[58] = (aid >> 8) & 255
        abDir[59] = (aid >> 16) & 255
        abDir[60] = (aid >> 24) & 255

        abDir[64] = browserFp.count
        abDir[65] = browserFp.count
 
        let sortedValues = sortIndex.map { abDir[$0] as? Int ?? 0 }
        let edgeFpArray = StringProcessor.toCharArray(browserFp).map { Int($0) }

        var abXor = (browserFp.count & 255) >> 8 & 255

        for index in 0..<(sortIndex2.count - 1) {
            if index == 0 {
                abXor = abDir[sortIndex2[index]] as? Int ?? 0
            }
            abXor ^= abDir[sortIndex2[index + 1]] as? Int ?? 0
        }

        var finalSortedValues = sortedValues
        finalSortedValues.append(contentsOf: edgeFpArray)
        finalSortedValues.append(abXor)

        let randomBytes = StringProcessor.generateRandomBytes()
        let transformedBytes = cryptoUtility.transformBytes(finalSortedValues)

        let abogusBytesStr = randomBytes + transformedBytes
        let randomUnicodeValues = randomBytes.map { Int($0.unicodeScalars.first?.value ?? 0) }
        let allUnicodeValues = randomUnicodeValues + cryptoUtility.rawTransformValues

        let abogus = cryptoUtility.abogusEncode(abogusBytesStr, selectedAlphabet: 0)
        let finalParams = "\(params)&a_bogus=\(abogus)"

        return (finalParams, abogus, userAgent, body)
    }
}
