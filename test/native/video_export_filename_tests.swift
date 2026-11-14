import Foundation

/// Compile with VideoExportFilename.swift to exercise both Files staging operations.
@main
struct VideoExportFilenameTests {
  enum Failure: Error { case assertion(String) }

  static func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !value() { throw Failure.assertion(message) }
  }

  static func main() {
    do { try run() } catch {
      print(error)
      exit(1)
    }
  }

  static func run() throws {
    let manager = FileManager.default
    let folder = manager.temporaryDirectory.appendingPathComponent("breeze-export-test-\(UUID())", isDirectory: true)
    try manager.createDirectory(at: folder, withIntermediateDirectories: false)
    defer { try? manager.removeItem(at: folder) }

    let title = String(repeating: "👩🏽‍🎨", count: 100)
    let mediaBytes = Data([0, 0, 0, 24, 102, 116, 121, 112])
    let archiveBytes = Data([80, 75, 3, 4])
    let media = folder.appendingPathComponent("managed.mp4")
    let archive = folder.appendingPathComponent("archive.zip")
    try mediaBytes.write(to: media)
    try archiveBytes.write(to: archive)

    let mediaCopy = folder.appendingPathComponent(VideoExportFilename.make(title, fallback: "Video", suffix: ".mp4"))
    let namedArchive = folder.appendingPathComponent(VideoExportFilename.make(title, fallback: "Comic", suffix: ".zip"))
    var failures: [String] = []
    for (label, action) in [("MP4 copy", { try manager.copyItem(at: media, to: mediaCopy) }),
                            ("ZIP rename", { try manager.moveItem(at: archive, to: namedArchive) })] {
      do { try action() } catch {
        let error = error as NSError
        let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError
        failures.append("\(label): \(error.domain) \(error.code), \(underlying?.domain ?? "") \(underlying?.code ?? 0)")
      }
    }
    if !failures.isEmpty {
      throw Failure.assertion(failures.joined(separator: "\n"))
    }
    try check(try Data(contentsOf: media) == mediaBytes, "export must keep the managed MP4")
    try check(try Data(contentsOf: mediaCopy) == mediaBytes, "MP4 staged bytes changed")
    try check(try Data(contentsOf: namedArchive) == archiveBytes, "ZIP staged bytes changed")

    let chinese = String(repeating: "字", count: 100)
    let emoji = String(repeating: "🍿", count: 100)
    try check(VideoExportFilename.make(chinese, fallback: "Comic", suffix: ".zip") == "\(chinese).zip", "ordinary CJK titles should keep their original length")
    try check(VideoExportFilename.make(emoji, fallback: "Video", suffix: ".mp4") == "\(emoji).mp4", "single emoji titles fit without truncation")
    try check(VideoExportFilename.make("  Comic / Title  ", fallback: "Comic", suffix: ".zip") == "Comic   Title.zip", "short titles should keep their existing sanitation")
    let singleLongCluster = "a" + String(repeating: "\u{0301}", count: 300)
    try check(VideoExportFilename.make(singleLongCluster, fallback: "Comic", suffix: ".zip") == "Comic.zip", "fallback should preserve an intact filename when even one cluster cannot fit")
    print("Video export filename: MP4 copy and ZIP rename preserve their bytes; title checks passed")
  }
}
