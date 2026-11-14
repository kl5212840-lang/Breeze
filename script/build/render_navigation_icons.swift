import Foundation
import CoreGraphics
import CoreText

// Export the exact Material glyphs used by Flutter as UIKit template vectors.
// Usage: swift script/build/render_navigation_icons.swift <MaterialIcons-Regular.otf> <Assets.xcassets>
let arguments = CommandLine.arguments
guard arguments.count == 3,
      let provider = CGDataProvider(url: URL(fileURLWithPath: arguments[1]) as CFURL),
      let graphicsFont = CGFont(provider) else {
  fatalError("Provide the Flutter Material Icons font and asset catalog paths")
}
let font = CTFontCreateWithGraphicsFont(graphicsFont, 24, nil, nil)
let icons: [(String, UInt32)] = [
  ("NavigationFollow", 0xF0027), // Icons.notifications_none_rounded
  ("NavigationFollowSelected", 0xE450), // Icons.notifications_active
]
for (name, codePoint) in icons {
  let directory = URL(fileURLWithPath: arguments[2]).appendingPathComponent(name + ".imageset")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let output = directory.appendingPathComponent(name + ".pdf")
  var box = CGRect(x: 0, y: 0, width: 24, height: 24)
  guard let consumer = CGDataConsumer(url: output as CFURL),
        let context = CGContext(consumer: consumer, mediaBox: &box, nil),
        let scalar = UnicodeScalar(codePoint) else { fatalError("Cannot create icon") }
  let text = NSAttributedString(string: String(scalar), attributes: [
    NSAttributedString.Key(kCTFontAttributeName as String): font,
  ])
  let line = CTLineCreateWithAttributedString(text)
  let width = CTLineGetTypographicBounds(line, nil, nil, nil)
  context.beginPDFPage(nil)
  context.textPosition = CGPoint(x: (24 - width) / 2,
    y: (24 - CTFontGetAscent(font) - CTFontGetDescent(font)) / 2 + CTFontGetDescent(font))
  CTLineDraw(line, context)
  context.endPDFPage()
  context.closePDF()
  let contents: [String: Any] = [
    "images": [["filename": name + ".pdf", "idiom": "universal"]],
    "info": ["author": "xcode", "version": 1],
    "properties": ["preserves-vector-representation": true, "template-rendering-intent": "template"],
  ]
  let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
  try data.write(to: directory.appendingPathComponent("Contents.json"))
  print("Generated \(name), 24pt template vector")
}
