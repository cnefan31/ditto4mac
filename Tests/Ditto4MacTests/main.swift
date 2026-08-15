import Foundation

// 极简测试框架：不依赖 XCTest，适配仅安装 CommandLineTools 的环境
private var failures = 0
private var currentTest = ""

private func assertEqual<T: Equatable>(
    _ expression: @autoclosure () -> T,
    _ expected: T,
    file: String = #file,
    line: Int = #line
) {
    let value = expression()
    guard value == expected else {
        print("FAIL [\(currentTest)] \(file):\(line) - expected \(expected), got \(value)")
        failures += 1
        return
    }
}

private func assertTrue(
    _ expression: @autoclosure () -> Bool,
    _ message: String = "",
    file: String = #file,
    line: Int = #line
) {
    guard expression() else {
        print("FAIL [\(currentTest)] \(file):\(line) - \(message)")
        failures += 1
        return
    }
}

private func assertFalse(
    _ expression: @autoclosure () -> Bool,
    _ message: String = "",
    file: String = #file,
    line: Int = #line
) {
    guard !expression() else {
        print("FAIL [\(currentTest)] \(file):\(line) - \(message)")
        failures += 1
        return
    }
}

private func test(_ name: String, _ body: () throws -> Void) {
    currentTest = name
    print("TEST \(name)")
    do {
        try body()
    } catch {
        print("FAIL [\(name)] unexpected error: \(error)")
        failures += 1
    }
}

private func makeTempDir() -> String {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("Ditto4MacTests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url.path
}

// MARK: - Tests

private func testSaveAndLoadItems() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(atPath: dir) }

    let storage = StorageService(storagePath: dir)
    let item = ClipboardItem()
    storage.saveItem(item, text: "hello")

    let items = storage.loadItems()
    assertEqual(items.count, 1)
    assertEqual(items.first?.id, item.id)
    assertEqual(storage.loadText(for: item), "hello")
}

private func testPinnedItemsComeFirstAndNormalItemsNewestFirst() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(atPath: dir) }

    let storage = StorageService(storagePath: dir)
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
    assertEqual(items.first?.id, pinned.id)
    assertTrue(items.first?.isPinned == true)

    let normalItems = items.filter { !$0.isPinned }
    assertEqual(normalItems.first?.id, newer.id)
}

private func testMaxItemsEvictsOldestUnpinned() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(atPath: dir) }

    let storage = StorageService(storagePath: dir)
    storage.saveSettings(AppSettings(maxItems: 2))

    let old = ClipboardItem(createdAt: Date(timeIntervalSinceNow: -200))
    let mid = ClipboardItem(createdAt: Date(timeIntervalSinceNow: -100))
    let new = ClipboardItem(createdAt: Date())

    storage.saveItem(old, text: "old")
    storage.saveItem(mid, text: "mid")
    storage.saveItem(new, text: "new")

    let items = storage.loadItems()
    assertEqual(items.count, 2)
    assertFalse(items.contains { $0.id == old.id })
    assertTrue(items.contains { $0.id == mid.id })
    assertTrue(items.contains { $0.id == new.id })
}

private func testSearchFiltersByText() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(atPath: dir) }

    let storage = StorageService(storagePath: dir)
    storage.saveItem(ClipboardItem(), text: "Hello World")
    storage.saveItem(ClipboardItem(), text: "Swift Programming")

    let results = storage.searchItems(query: "world")
    assertEqual(results.count, 1)
    assertEqual(storage.loadText(for: results[0]), "Hello World")
}

private func testSettingsPersistAcrossReload() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(atPath: dir) }

    let storage = StorageService(storagePath: dir)
    storage.saveSettings(AppSettings(maxItems: 42, displayCount: 7))

    let reloaded = StorageService(storagePath: dir)
    assertEqual(reloaded.loadSettings().maxItems, 42)
    assertEqual(reloaded.loadSettings().displayCount, 7)
}

private func testMigrateStorageCopiesDataAndRemovesOldSiblingPath() throws {
    let dir = makeTempDir()
    let newPath = dir + ".new"
    defer {
        try? FileManager.default.removeItem(atPath: dir)
        try? FileManager.default.removeItem(atPath: newPath)
    }

    let storage = StorageService(storagePath: dir)
    let item = ClipboardItem()
    storage.saveItem(item, text: "migrate me")

    assertTrue(storage.migrateStorage(to: newPath))

    assertEqual(storage.loadItems().count, 1)
    assertEqual(storage.loadText(for: item), "migrate me")
    assertEqual(storage.loadSettings().storagePath, newPath)
    assertFalse(FileManager.default.fileExists(atPath: dir))
    assertTrue(FileManager.default.fileExists(atPath: newPath))
}

private func testCorruptedIndexIsBackedUpAndRebuilt() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(atPath: dir) }

    try Data("not valid json".utf8)
        .write(to: URL(fileURLWithPath: dir).appendingPathComponent("index.json"))

    let storage = StorageService(storagePath: dir)
    assertTrue(FileManager.default.fileExists(
        atPath: URL(fileURLWithPath: dir).appendingPathComponent("index.json.bak").path
    ))
    assertEqual(storage.loadItems().count, 0)
}

// MARK: - Run

test("testSaveAndLoadItems", testSaveAndLoadItems)
test("testPinnedItemsComeFirstAndNormalItemsNewestFirst", testPinnedItemsComeFirstAndNormalItemsNewestFirst)
test("testMaxItemsEvictsOldestUnpinned", testMaxItemsEvictsOldestUnpinned)
test("testSearchFiltersByText", testSearchFiltersByText)
test("testSettingsPersistAcrossReload", testSettingsPersistAcrossReload)
test("testMigrateStorageCopiesDataAndRemovesOldSiblingPath", testMigrateStorageCopiesDataAndRemovesOldSiblingPath)
test("testCorruptedIndexIsBackedUpAndRebuilt", testCorruptedIndexIsBackedUpAndRebuilt)

if failures > 0 {
    print("FAILED: \(failures) test(s) failed")
    exit(1)
} else {
    print("ALL TESTS PASSED")
}
