// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation


protocol LiveParse {
    
    /**
     获取平台直播分类。
     
     - Returns: 平台直播分类（包含子分类）。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func getCategoryList() async throws -> [LiveMainListModel]
    
    
    /**
     获取直播分类下的房间信息。
     
     - Parameters:
     - id: 对应平台分类id, 抖音原始字段为:id_str。
     - parentId: 对应平台id, b站抖音必填（抖音对应原始字段为: type），斗鱼虎牙不需要。
     
     - Returns: 主播和直播间信息。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel]
    
    
    /**
     获取直播源。
     
     - Parameters:
     - roomId: 对应平台主播房间号（并不一定url中出现的房间号， 抖音对应原始字段为webrid）。
     - userId: 对应平台用户id（抖音对应原始字段为room_id_str）。
     
     - Warning: 斗鱼流程可能有些不同，需要首先调用本方法，如需要切换cdn/清晰度，需要再次调用getRealPlayArgs(roomId: String, rate: Int, cdn: String?),并且目前相当于只返回一个清晰度和CDN的链接
     
     - Returns: 直播真实地址和与相关清晰度字段。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel]
    
    
    /**
     根据关键字搜索主播。
     
     - Parameters:
     - keyword: 关键词。
     - page: 分页。
     
     - Returns: 对应平台主播信息。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel]
    
    
    /**
     刷新用户信息（如用户进行收藏，需要单独更新主播直播标题封面等信息）。
     
     - Parameters:
     - roomId: 对应平台主播房间号（并不一定url中出现的房间号， 抖音对应原始字段为webrid）。
     - userId: 对应平台用户id（抖音对应原始字段为room_id_str）。
     
     - Returns: 对应平台主播信息。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel
    
    
    /**
     获取对应主播直播状态。
     
     - Parameters:
     - roomId: 对应平台主播房间号（并不一定url中出现的房间号， 抖音对应原始字段为webrid）。
     - userId: 对应平台用户id（抖音对应原始字段为room_id_str）。
     
     - Returns: 对应平台主播直播状态。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func getLiveState(roomId: String, userId: String?) async throws -> LiveState
    
    /**
     通过分享链接/房间号/分享码/短链接等方式获取用户信息。
     
     - Parameters:
     - shareCode: shareCode
        B站：【暖雪玩玩-哔哩哔哩直播】 https://b23.tv/jeBazlm || https://live.bilibili.com/404 || 404
     
        Douyu: https://www.douyu.com/7180846 || 7180846 || https://www.douyu.com/lpl
     
        Huya: 霸哥(房间号189201)正在直播"冠军园区！大师局9999目前3170" 分享自 @虎牙直播https://m.huya.com/189201?shareid=16890536033617446582&shareUid=13794774&source=ios&pid=1724691&liveid=7312248923907638255&platform=7&from=cpy&invite_code=HY76QLTk || https://www.huya.com/7180846 || 7180846 || https://www.huya.com/lpl
     
        Douyin: 2- #在抖音，记录美好生活#【交个朋友直播间】正在直播，来和我一起支持Ta吧。复制下方链接，打开【抖音】，直接观看直播！ https://v.douyin.com/i8rhQQ2t/ 2@4.com 12/18 || https://live.douyin.com/168465302284 || 168465302284
     
     - Returns: 对应平台主播信息。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel
}
