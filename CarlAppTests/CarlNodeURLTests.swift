import XCTest
@testable import CarlApp

/// Pins `CarlNodeURL.parse` to the QR string the firmware actually renders —
/// `Project-Carl/firmware/node-sensor/src/ui/oled.cpp` and
/// `Project-Carl/tools/provision.py` both produce
/// `CARL://<12-hex-MAC>/<32-hex-key>` (uppercase, no query string, no "node"
/// host). The parser previously expected the old
/// `carl://node?mac=...&key=...` shape and would reject every real QR code
/// with `.wrongHost` — this had zero test coverage, which is how the drift
/// happened silently. Do not change this format without confirming the
/// firmware side first.
final class CarlNodeURLTests: XCTestCase {
    /// Exact string from oled.cpp's own doc comment, byte for byte.
    private let realFirmwareQR = "CARL://AABBCCDDEEFF/4B1F9C8A3E2D6F70B15C4D8A9E3F2C10"

    func test_parsesRealFirmwareFormat() throws {
        let parsed = try CarlNodeURL.parse(realFirmwareQR)
        XCTAssertEqual(parsed.mac, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(parsed.keyHex, "4b1f9c8a3e2d6f70b15c4d8a9e3f2c10")
    }

    func test_parsesLowercaseSchemeAndHost() throws {
        let parsed = try CarlNodeURL.parse("carl://aabbccddeeff/4b1f9c8a3e2d6f70b15c4d8a9e3f2c10")
        XCTAssertEqual(parsed.mac, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(parsed.keyHex, "4b1f9c8a3e2d6f70b15c4d8a9e3f2c10")
    }

    func test_rejectsWrongScheme() {
        XCTAssertThrowsError(try CarlNodeURL.parse("http://aabbccddeeff/4b1f9c8a3e2d6f70b15c4d8a9e3f2c10")) { error in
            XCTAssertEqual(error as? CarlNodeURL.ParseError, .wrongScheme)
        }
    }

    func test_rejectsMissingKey() {
        XCTAssertThrowsError(try CarlNodeURL.parse("CARL://AABBCCDDEEFF/")) { error in
            XCTAssertEqual(error as? CarlNodeURL.ParseError, .missingKey)
        }
    }

    func test_rejectsBadKeyLength() {
        XCTAssertThrowsError(try CarlNodeURL.parse("CARL://AABBCCDDEEFF/deadbeef")) { error in
            XCTAssertEqual(error as? CarlNodeURL.ParseError, .badKeyLength)
        }
    }

    func test_rejectsOldQueryStringFormat() {
        // The format this app used to expect, before the firmware shipped
        // its actual path-based scheme. Must fail cleanly, not silently
        // "succeed" by misparsing the query string as a path.
        XCTAssertThrowsError(
            try CarlNodeURL.parse("carl://node?mac=AA:BB:CC:DD:EE:FF&key=4b1f9c8a3e2d6f70b15c4d8a9e3f2c10")
        )
    }

    func test_manualEntry_matchesQRParseResult() throws {
        let fromQR = try CarlNodeURL.parse(realFirmwareQR)
        let fromManualEntry = try CarlNodeURL.from(mac: "AA:BB:CC:DD:EE:FF", key: "4B1F9C8A3E2D6F70B15C4D8A9E3F2C10")
        XCTAssertEqual(fromQR, fromManualEntry)
    }
}
