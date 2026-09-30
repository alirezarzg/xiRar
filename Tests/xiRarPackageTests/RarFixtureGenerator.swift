import Foundation

enum RarFixtureCRC32 {
    private static let table: [UInt32] = (0..<256).map { index -> UInt32 in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) != 0 ? 0xedb88320 ^ (value >> 1) : value >> 1
        }
        return value
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xff)] ^ (crc >> 8)
        }
        return crc ^ 0xffffffff
    }
}

enum Rar3FixtureGenerator {
    struct Entry {
        let nameUnits: [UInt16]
        let content: Data

        static func file(name: String, content: Data) -> Entry {
            Entry(nameUnits: Array(name.utf16), content: content)
        }

        static func file(nameUnits: [UInt16], content: Data) -> Entry {
            Entry(nameUnits: nameUnits, content: content)
        }
    }

    private static let marker = Data([0x52, 0x61, 0x72, 0x21, 0x1a, 0x07, 0x00])
    private static let headMain: UInt8 = 0x73
    private static let headFile: UInt8 = 0x74
    private static let headEnd: UInt8 = 0x7b
    private static let fileFlags: UInt16 = 0x8000 | 0x0200 | 0x0020
    private static let endFlags: UInt16 = 0x4000
    private static let hostWindows: UInt8 = 2
    private static let unpackVersion: UInt8 = 29
    private static let methodStore: UInt8 = 0x30
    private static let dosTime: UInt32 = 0x3ee6_8602
    private static let archiveAttribute: UInt32 = 0x20

    static func archive(_ entries: [Entry]) -> Data {
        var out = marker
        out.append(block(type: headMain, flags: 0, fields: Data(count: 6)))
        for entry in entries {
            out.append(fileBlock(entry))
        }
        out.append(block(type: headEnd, flags: endFlags, fields: Data()))
        return out
    }

    static func encodedName(_ units: [UInt16]) -> Data {
        var out = Data(units.map { $0 < 0x80 ? UInt8($0) : UInt8(ascii: "?") })
        out.append(0)
        out.append(0)
        var index = 0
        while index < units.count {
            out.append(0xaa)
            for unit in units[index..<min(index + 4, units.count)] {
                out.append(le16(unit))
            }
            index += 4
        }
        return out
    }

    private static func fileBlock(_ entry: Entry) -> Data {
        let name = encodedName(entry.nameUnits)
        let size = UInt32(entry.content.count)
        var fields = Data()
        fields.append(le32(size))
        fields.append(le32(size))
        fields.append(hostWindows)
        fields.append(le32(RarFixtureCRC32.checksum(entry.content)))
        fields.append(le32(dosTime))
        fields.append(unpackVersion)
        fields.append(methodStore)
        fields.append(le16(UInt16(name.count)))
        fields.append(le32(archiveAttribute))
        fields.append(name)
        var out = block(type: headFile, flags: fileFlags, fields: fields)
        out.append(entry.content)
        return out
    }

    static func block(type: UInt8, flags: UInt16, fields: Data) -> Data {
        var body = Data([type])
        body.append(le16(flags))
        body.append(le16(UInt16(7 + fields.count)))
        body.append(fields)
        var out = le16(UInt16(RarFixtureCRC32.checksum(body) & 0xffff))
        out.append(body)
        return out
    }

    private static func le16(_ value: UInt16) -> Data {
        Data([UInt8(value & 0xff), UInt8(value >> 8)])
    }

    private static func le32(_ value: UInt32) -> Data {
        Data([UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff), UInt8(value >> 24)])
    }
}

enum Rar5FixtureGenerator {
    private static let signature = Data([0x52, 0x61, 0x72, 0x21, 0x1a, 0x07, 0x01, 0x00])

    static func archive(_ entries: [(name: String, content: Data)]) -> Data {
        var out = signature
        out.append(block(type: 1, fields: vint(0)))
        for entry in entries {
            let nameBytes = Data(entry.name.utf8)
            var fields = Data()
            fields.append(vint(0x04))
            fields.append(vint(entry.content.count))
            fields.append(vint(0))
            fields.append(le32(RarFixtureCRC32.checksum(entry.content)))
            fields.append(vint(0))
            fields.append(vint(0))
            fields.append(vint(nameBytes.count))
            fields.append(nameBytes)
            out.append(block(type: 2, fields: fields, data: entry.content))
        }
        out.append(block(type: 5, fields: vint(0)))
        return out
    }

    private static func block(type: Int, fields: Data, data: Data = Data()) -> Data {
        var body = vint(type)
        body.append(vint(data.isEmpty ? 0 : 0x02))
        if !data.isEmpty { body.append(vint(data.count)) }
        body.append(fields)
        var payload = vint(body.count)
        payload.append(body)
        var out = le32(RarFixtureCRC32.checksum(payload))
        out.append(payload)
        out.append(data)
        return out
    }

    private static func vint(_ value: Int) -> Data {
        var remaining = UInt64(value)
        var out = Data()
        repeat {
            let low = UInt8(remaining & 0x7f)
            remaining >>= 7
            out.append(remaining == 0 ? low : low | 0x80)
        } while remaining != 0
        return out
    }

    private static func le32(_ value: UInt32) -> Data {
        Data([UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff), UInt8(value >> 24)])
    }
}
