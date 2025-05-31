import XCTest
@testable import CantinarrModels

final class ModelDecodingTests: XCTestCase {
    func testRadarrSystemStatusDecoding() throws {
        let json = """
        {"appName":"Radarr","version":"4.3.2","buildTime":"2021-05-01T12:00:00Z","osName":"Linux","osVersion":"5.15","isDebug":false}
        """
        let data = json.data(using: .utf8)!
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let status = try dec.decode(RadarrSystemStatus.self, from: data)
        XCTAssertEqual(status.appName, "Radarr")
        XCTAssertEqual(status.osName, "Linux")
    }

    func testRadarrMovieFileDecoding() throws {
        let json = """
        {"id":10,"relativePath":"Movie (2020)/movie.mkv","path":"/movies/Movie (2020)/movie.mkv","size":123456789,"dateAdded":"2020-12-04T00:00:00Z","mediaInfo":null,"movieId":1,"quality":{"quality":{"id":1,"name":"HD-1080p","source":"bluray","resolution":1080},"revision":{"version":1,"real":0,"isRepack":false}}}
        """
        let data = json.data(using: .utf8)!
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let file = try dec.decode(RadarrMovieFile.self, from: data)
        XCTAssertEqual(file.movieId, 1)
        XCTAssertEqual(file.quality?.quality?.name, "HD-1080p")
    }

    func testRadarrMovieHistoryRecordDecoding() throws {
        let json = """
        {"id":1,"movieId":1,"sourceTitle":"Movie (2020)","quality":{"quality":{"id":1,"name":"HD-1080p","source":"bluray","resolution":1080},"revision":{"version":1,"real":0,"isRepack":false}},"qualityCutoffNotMet":false,"date":"2021-05-10T00:00:00Z","eventType":"downloadFolderImported","data":null,"downloadId":"abc123"}
        """
        let data = json.data(using: .utf8)!
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let record = try dec.decode(RadarrMovieHistoryRecord.self, from: data)
        XCTAssertEqual(record.downloadId, "abc123")
    }

    func testUserDecoding() throws {
        let json = """
        {"id":1,"username":"test","email":"user@example.com","permissions":1,"requestCount":0,"avatar":"/avatar.png","plexId":123,"plexUsername":"plex","userType":"admin"}
        """
        let data = json.data(using: .utf8)!
        let user = try JSONDecoder().decode(User.self, from: data)
        XCTAssertEqual(user.plexUsername, "plex")
        XCTAssertEqual(user.userType, "admin")
    }
}
