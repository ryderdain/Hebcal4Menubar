//
//  main.swift
//  HebrewDateMenubar
//
//  Entry point. We create the application manually (rather than using
//  @main on the delegate) so this works whether you build via Xcode or
//  via the command line with swiftc.
//

import Cocoa

let app = NSApplication.shared

// .accessory = no Dock icon, no main menu bar — just our status item.
// This is the standard policy for menubar-only ("agent") apps.
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
