import XCTest
@testable import Ditto4Mac

final class StorageServiceTests: XCTestCase {
    private var tempDir: URL!
    private var storagePath: String!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Ditto4MacTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storagePath = tempDir.path
    }

    override func tearDownWithError() throws {
        if let tempDir {
            let sibling = tempDir.path + ".new"
            try? FileManager.default.removeItem(atPath: sibling)
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    func testSaveAndLoadItems() throws {
        let storage = StorageService(storagePath: storagePath)
        let item = ClipboardItem()
        storage.saveItem(item, text: "hello")

        let items = storage.loadItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, item.id)
        XCTAssertEqual(storage.loadText(for: item), "hello")
    }

    func testPinnedItemsComeFirstAndNormalItemsNewestFirst() throws {
        let storage = StorageService(storagePath: storagePath)
        let older = ClipboardItem(createdAt: Date(timeIntervalSinceNow: -200))
        let newer = ClipboardItem(createdAt: Date(timeIntervalSinceNow: -100))
        let pinned = ClipboardItem(
            createdAt: Date(timeIntervalSinceNow: -1000),
            isPinned: true,
            pinnedAt: Date()
        )

        storage.saveItem(older, text: "older")
        storage.saveItem(newer, text: "newer")
        storage.saveItem(pinned, text: "pinned")

        let items = storage.loadItems()
        XCTAssertEqual(items.first?.id, pinned.id)
        XCTAssertTrue(items.first?.isPinned == true)

        let normalItems = items.filter { !$0.isPinned }
        XCTAssertEqual(normalItems.first?.id, newer.id)
    }

    func testMaxItemsEvictsOldestUnpinned() throws {
        let storage = StorageService(storagePath: storagePath)
        storage.saveSettings(AppSettings(maxItems: 2))

        let old = ClipboardItem(createdAt: Date(timeIntervalSinceNow: -200))
        let mid = ClipboardItem(createdAt: Date(timeIntervalSinceNow: -100))
        let new = ClipboardItem(createdAt: Date())

        storage.saveItem(old, text: "old")
        storage.saveItem(mid, text: "mid")
        storage.saveItem(new, text: "new")

        let items = storage.loadItems()
        XCTAssertEqual(items.count, 2)
        XCTAssertFalse(items.contains { $0.id == old.id })
        XCTAssertTrue(items.contains { $0.id == mid.id })
        XCTAssertTrue(items.contains { $0.id == new.id })
    }

    func testSearchFiltersByText() throws {
        let storage = StorageService(storagePath: storagePath)
        storage.saveItem(ClipboardItem(), text: "Hello World")
        storage.saveItem(ClipboardItem(), text: "Swift Programming")

        let results = storage.searchItems(query: "world")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(storage.loadText(for: results[0]), "Hello World")
    }

    func testSettingsPersistAcrossReload() throws {
        let storage = StorageService(storagePath: storagePath)
        storage.saveSettings(AppSettings(maxItems: 42, displayCount: 7))

        let reloaded = StorageService(storagePath: storagePath)
        XCTAssertEqual(reloaded.loadSettings().maxItems, 42)
        XCTAssertEqual(reloaded.loadSettings().displayCount, 7)
    }

    func testMigrateStorageCopiesDataAndRemovesOldSiblingPath() throws {
        let storage = StorageService(storagePath: storagePath)
        let item = ClipboardItem()
        storage.saveItem(item, text: "migrate me")

        let newPath = tempDir.path + ".new"
        XCTAssertTrue(storage.migrateStorage(to: newPath))

        XCTAssertEqual(storage.loadItems().count, 1)
        XCTAssertEqual(storage.loadText(for: item), "migrate me")
        XCTAssertEqual(storage.loadSettings().storagePath, newPath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storagePath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newPath))
    }

    func testCorruptedIndexIsBackedUpAndRebuilt() throws {
        try Data("not valid json".utf8)
            .write(to: tempDir.appendingPathComponent("index.json"))

        let storage = StorageService(storagePath: storagePath)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("index.json.bak").path
        ))
        XCTAssertEqual(storage.loadItems().count, 0)
    }
}
