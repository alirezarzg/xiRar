import XCTest
import xiRar

final class NameDecodingTests: XCTestCase {
    private let supplementaryName = "\u{1D400}\u{1D401} page \u{1F600}.png"
    private let bmpName = "\u{0421}\u{0442}\u{0440}\u{0430}\u{043D}\u{0438}\u{0446}\u{0430} 01.png"
    private let malformedNames: [(label: String, units: [UInt16])] = [
        ("lone high surrogate", [0xD835] + Array(".png".utf16)),
        ("lone low surrogate", [0xDC00] + Array("x.png".utf16)),
        ("reversed pair", [0xDC00, 0xD835] + Array(".png".utf16)),
        ("trailing high surrogate", Array("x.png".utf16) + [0xD835])
    ]

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("xiRarNameTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func archive(_ data: Data, named name: String = "fixture.rar") throws -> URKArchive {
        let url = try temporaryDirectory().appendingPathComponent(name)
        try data.write(to: url)
        return try URKArchive(url: url)
    }

    private func content(_ seed: UInt8) -> Data {
        Data((0..<64).map { UInt8(truncatingIfNeeded: Int($0) &* 7 &+ Int(seed)) })
    }

    private func assertUndecodable(_ label: String, file: StaticString = #filePath, line: UInt = #line, _ body: () throws -> Void) {
        XCTAssertThrowsError(try body(), label, file: file, line: line) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, URKErrorDomain, label, file: file, line: line)
            XCTAssertEqual(nsError.code, URKErrorCode.undecodableFilename.rawValue, label, file: file, line: line)
        }
    }

    func testGeneratorHeaderChecksumsMatchWinRARArchive() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "unicode2", withExtension: "rar", subdirectory: "Fixtures"))
        let real = try Data(contentsOf: url)
        let generatedMain = Rar3FixtureGenerator.block(type: 0x73, flags: 0, fields: Data(count: 6))
        XCTAssertEqual(generatedMain, real.subdata(in: 7..<20))
        let generatedEnd = Rar3FixtureGenerator.block(type: 0x7b, flags: 0x4000, fields: Data())
        XCTAssertEqual(generatedEnd, real.subdata(in: (real.count - 7)..<real.count))
    }

    func testWinRARSupplementaryPlaneNamesDecode() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "unicode2", withExtension: "rar", subdirectory: "Fixtures"))
        let archive = try URKArchive(url: url)
        let names = try archive.listFilenames()
        XCTAssertEqual(names, [
            "\u{1D400}\u{1D401}\u{1D401}\u{1D402}.txt",
            "\u{0443}\u{0438}\u{0438}\u{043E}\u{043E}\u{0442}\u{0438}\u{0432}\u{043B}.txt"
        ])
    }

    func testRar3SupplementaryPlaneNameDecodesAndExtracts() throws {
        let data = Rar3FixtureGenerator.archive([
            .file(name: supplementaryName, content: content(1)),
            .file(name: "plain.png", content: content(2))
        ])
        let archive = try archive(data)
        XCTAssertEqual(try archive.listFileInfo().map(\.filename), [supplementaryName, "plain.png"])

        let destination = try temporaryDirectory()
        try archive.extractFiles(to: destination.path, overwrite: true)
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent(supplementaryName)), content(1))
        XCTAssertEqual(try archive.extractData(fromFile: supplementaryName), content(1))
    }

    func testRar3BasicPlaneNameIsUnchanged() throws {
        let data = Rar3FixtureGenerator.archive([
            .file(name: bmpName, content: content(3)),
            .file(name: "page.png", content: content(4))
        ])
        XCTAssertEqual(try archive(data).listFilenames(), [bmpName, "page.png"])
    }

    func testRar5SupplementaryPlaneNameIsUnchanged() throws {
        let data = Rar5FixtureGenerator.archive([
            (supplementaryName, content(5)),
            (bmpName, content(6))
        ])
        let archive = try archive(data)
        XCTAssertEqual(try archive.listFilenames(), [supplementaryName, bmpName])
        XCTAssertEqual(try archive.extractData(fromFile: supplementaryName), content(5))
    }

    func testMalformedNameIsATypedErrorInEveryListingAPI() throws {
        for malformed in malformedNames {
            let data = Rar3FixtureGenerator.archive([
                .file(name: "a.png", content: content(7)),
                .file(nameUnits: malformed.units, content: content(8)),
                .file(name: "z.png", content: content(9))
            ])
            let archive = try archive(data)
            assertUndecodable("listFileInfo \(malformed.label)") { _ = try archive.listFileInfo() }
            assertUndecodable("listFilenames \(malformed.label)") { _ = try archive.listFilenames() }
            assertUndecodable("listVolumeURLs \(malformed.label)") { _ = try archive.listVolumeURLs() }

            var seen: [String] = []
            assertUndecodable("iterateFileInfo \(malformed.label)") {
                try archive.iterateFileInfo { info, _ in seen.append(info.filename) }
            }
            XCTAssertEqual(seen, ["a.png"], malformed.label)

            var performed: [String] = []
            assertUndecodable("performOnFiles \(malformed.label)") {
                try archive.performOnFiles { info, _ in performed.append(info.filename) }
            }
            assertUndecodable("performOnData \(malformed.label)") {
                try archive.performOnData { info, _, _ in performed.append(info.filename) }
            }
            XCTAssertEqual(performed, [], malformed.label)
            XCTAssertFalse(archive.checkDataIntegrity(), malformed.label)
        }
    }

    func testMalformedNameIsATypedErrorInEveryExtractionAPI() throws {
        for malformed in malformedNames {
            let data = Rar3FixtureGenerator.archive([
                .file(name: "a.png", content: content(7)),
                .file(nameUnits: malformed.units, content: content(8)),
                .file(name: "z.png", content: content(9))
            ])
            let archive = try archive(data)

            let destination = try temporaryDirectory()
            var progressNames: [String] = []
            assertUndecodable("extractFiles \(malformed.label)") {
                try archive.extractFiles(to: destination.path, overwrite: true) { info, _ in
                    progressNames.append(info.filename)
                }
            }
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), [], malformed.label)
            XCTAssertEqual(progressNames, [], malformed.label)

            assertUndecodable("extractData \(malformed.label)") { _ = try archive.extractData(fromFile: "z.png") }

            var chunks = 0
            assertUndecodable("extractBufferedData \(malformed.label)") {
                try archive.extractBufferedData(fromFile: "z.png") { _, _ in chunks += 1 }
            }
            XCTAssertEqual(chunks, 0, malformed.label)
        }
    }

    func testSingleFileExtractionBeforeAMalformedEntryStillReadsItsTarget() throws {
        let data = Rar3FixtureGenerator.archive([
            .file(name: "a.png", content: content(7)),
            .file(nameUnits: malformedNames[0].units, content: content(8))
        ])
        XCTAssertEqual(try archive(data).extractData(fromFile: "a.png"), content(7))
    }

    func testFirstEntryMalformedIsATypedError() throws {
        let data = Rar3FixtureGenerator.archive([
            .file(nameUnits: malformedNames[0].units, content: content(8))
        ])
        let archive = try archive(data)
        assertUndecodable("listFileInfo first entry") { _ = try archive.listFileInfo() }
        XCTAssertFalse(archive.isPasswordProtected())
    }
}
