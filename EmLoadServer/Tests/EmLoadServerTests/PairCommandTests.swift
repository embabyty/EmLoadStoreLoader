import Foundation
import XCTest
@testable import EmLoadServer

final class PairCommandTests: XCTestCase {
    func testParseRequiresValidUDIDAndOutputPath() throws {
        let command = try PairCommand.parse(arguments: [
            "--udid", "0123456789ABCDEF",
            "--output", "/tmp/pairing.plist"
        ])

        XCTAssertEqual(command.udid, "0123456789ABCDEF")
        XCTAssertEqual(command.outputURL.path, "/tmp/pairing.plist")
    }

    func testParseRejectsPathLikeUDID() {
        XCTAssertThrowsError(try PairCommand.parse(arguments: [
            "--udid", "../pairing",
            "--output", "/tmp/pairing.plist"
        ]))
    }

    func testRunPairsValidatesAndWritesPrivatePairingRecord() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let lockdown = root.appendingPathComponent("lockdown")
        let outputDirectory = root.appendingPathComponent("output")
        let toolDirectory = root.appendingPathComponent("bin")
        try fileManager.createDirectory(at: lockdown, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: toolDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let udid = "0123456789ABCDEF"
        let record = try PropertyListSerialization.data(
            fromPropertyList: ["HostID": "test-host"],
            format: .xml,
            options: 0
        )
        try record.write(to: lockdown.appendingPathComponent("\(udid).plist"))

        let toolURL = toolDirectory.appendingPathComponent("idevicepair")
        try """
        #!/bin/sh
        printf '%s\\n' "$*" >> "$EMLOADSERVER_TEST_CALLS"
        exit 0
        """.write(to: toolURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: toolURL.path)

        let callsURL = root.appendingPathComponent("calls.txt")
        let outputURL = outputDirectory.appendingPathComponent("pairing.plist")
        let command = try PairCommand.parse(arguments: [
            "--udid", udid,
            "--output", outputURL.path,
            "--record-dir", lockdown.path
        ])
        try command.run(
            executableURL: toolURL,
            environment: ["EMLOADSERVER_TEST_CALLS": callsURL.path]
        )

        XCTAssertEqual(try String(contentsOf: callsURL), "-u \(udid) pair\n-u \(udid) validate\n")
        XCTAssertEqual(try Data(contentsOf: outputURL), record)
        let attributes = try fileManager.attributesOfItem(atPath: outputURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testRunDoesNotOverwriteExistingPairingFile() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let outputURL = root.appendingPathComponent("pairing.plist")
        try Data("keep".utf8).write(to: outputURL)
        let command = try PairCommand.parse(arguments: [
            "--udid", "0123456789ABCDEF",
            "--output", outputURL.path
        ])

        XCTAssertThrowsError(try command.run(executableURL: URL(fileURLWithPath: "/usr/bin/true")))
        XCTAssertEqual(try Data(contentsOf: outputURL), Data("keep".utf8))
    }
}

final class HostSignInTests: XCTestCase {
    func testLoginOptionsNeverAcceptPasswordArguments() throws {
        let options = try LoginOptions.parse(arguments: [
            "--apple-id", "account@example.com",
            "--server", "SideStore (New)"
        ])
        XCTAssertEqual(options.appleID, "account@example.com")
        XCTAssertEqual(options.server, "SideStore (New)")
        XCTAssertThrowsError(try LoginOptions.parse(arguments: ["--password", "secret"]))
    }

    func testRegistryKeepsOnlyUniqueHTTPSMacADIServers() throws {
        let data = Data(
            """
            {
              "servers": [
                {"name":"SideStore (New)","address":"https://new.ani.sidestore.io","kind":2},
                {"name":"Legacy","address":"https://legacy.example","kind":1},
                {"name":"Insecure","address":"http://unsafe.example","kind":2},
                {"name":"Duplicate","address":"https://new.ani.sidestore.io","kind":2}
              ]
            }
            """.utf8
        )

        let servers = try AnisetteServerRegistry.parse(data)
        XCTAssertEqual(servers.map(\.name), ["SideStore (New)"])
        XCTAssertEqual(
            try AnisetteServerRegistry.select(server: nil, from: servers).address,
            AnisetteServerRegistry.defaultAddress
        )
        XCTAssertEqual(
            try AnisetteServerRegistry.select(
                server: nil,
                preferredAddress: "https://new.ani.sidestore.io",
                from: servers
            ).name,
            "SideStore (New)"
        )
        XCTAssertThrowsError(
            try AnisetteServerRegistry.select(server: "Legacy", from: servers)
        )
    }
}
