import Foundation

enum VideoExportFilename {
  static func make(_ title: String, fallback: String, suffix: String) -> String {
    let unsafe = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/\\:?%*|\"<>"))
    let safe = title.components(separatedBy: unsafe).joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    // Reserve space for the extension and allow for filesystem normalization.
    // A Swift Character can take several UTF-16 code units.
    var remaining = 255 - suffix.utf16.count
    var stem = ""
    for character in safe {
      let units = String(character).decomposedStringWithCanonicalMapping.utf16.count
      guard units <= remaining else { break }
      stem.append(character)
      remaining -= units
    }
    stem = stem.trimmingCharacters(in: .whitespacesAndNewlines)
    return (stem.isEmpty ? fallback : stem) + suffix
  }
}
