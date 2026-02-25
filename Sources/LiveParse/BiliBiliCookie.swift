//
//  BiliBiliCookie.swift
//  LiveParse
//
//  从 Bilibili.swift 提取，用于弹幕连接等场景的 Cookie 存取。
//

import Foundation

public struct BiliBiliCookie: Sendable {
    public static var cookie: String {
        get { UserDefaults.standard.string(forKey: "SimpleLive.Setting.BilibiliCookie") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "SimpleLive.Setting.BilibiliCookie") }
    }

    public static var uid: String {
        get { UserDefaults.standard.string(forKey: "LiveParse.Bilibili.uid") ?? "0" }
        set { UserDefaults.standard.set(newValue, forKey: "LiveParse.Bilibili.uid") }
    }
}
