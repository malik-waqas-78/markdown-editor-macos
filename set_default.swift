#!/usr/bin/env swift
import Foundation
import CoreServices

// Makes Markdown Editor the default app for markdown files (.md / .markdown).
// Only claims the markdown content type — plain-text files are left untouched.
let bundleID = "com.citizenknowledge.MarkdownEditor"
let markdownUTI = "net.daringfireball.markdown"

let status = LSSetDefaultRoleHandlerForContentType(
    markdownUTI as CFString,
    .all,
    bundleID as CFString
)

if status == noErr {
    print("✅ Markdown Editor is now the default app for .md / .markdown files.")
} else {
    print("⚠️ Could not set default handler (status \(status)).")
    print("   Set it manually: right-click a .md file → Get Info → Open with → Markdown Editor → Change All.")
}
