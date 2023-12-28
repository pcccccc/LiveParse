import XCTest
@testable import LiveParse

final class LiveParseTests: XCTestCase {
    func testExample() throws {
        //bilibili
        Task {
            let categoryList = try await Bilibili.getCategoryList()
            let roomList = try await Bilibili.getRoomList(id: categoryList.first?.subList.first?.id ?? "", parentId: categoryList.first?.id, page: 1)
            _ = try await Bilibili.getLiveLastestInfo(roomId: roomList.first?.roomId ?? "", userId: nil)
        }
    }
}
