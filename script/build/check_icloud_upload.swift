import Foundation

let keys: Set<URLResourceKey> = [
    .isUbiquitousItemKey,
    .ubiquitousItemIsUploadedKey,
    .ubiquitousItemIsUploadingKey
]

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: swift check_icloud_upload.swift FILE [FILE...]\n", stderr)
    exit(2)
}

var complete = true
for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    do {
        let state = try url.resourceValues(forKeys: keys)
        let uploaded = state.isUbiquitousItem == true
            && state.ubiquitousItemIsUploaded == true
            && state.ubiquitousItemIsUploading == false
        if !uploaded {
            fputs("Upload not complete: \(path)\n", stderr)
            complete = false
        }
    } catch {
        fputs("Cannot read iCloud status for \(path): \(error)\n", stderr)
        complete = false
    }
}
exit(complete ? 0 : 1)
