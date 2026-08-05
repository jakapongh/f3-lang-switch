import AppKit
import Carbon
import Foundation

/// Swallows Mission Control key (keycode 160 / keyboard F3 without Fn)
/// and toggles ABC ↔ Thai.
final class MissionControlRemapper {
  private static let missionControlKeycode: Int64 = 160
  private static let debounceSeconds: TimeInterval = 0.25

  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var lastToggleAt: TimeInterval = 0
  private(set) var isRunning = false

  func start() {
    guard !isRunning else { return }
    guard AXIsProcessTrusted() else { return }

    let mask =
      CGEventMask(1 << CGEventType.keyDown.rawValue)
      | CGEventMask(1 << CGEventType.keyUp.rawValue)

    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: { proxy, type, event, refcon in
          guard let refcon else {
            return Unmanaged.passUnretained(event)
          }
          let remapper = Unmanaged<MissionControlRemapper>
            .fromOpaque(refcon)
            .takeUnretainedValue()
          return remapper.handle(proxy: proxy, type: type, event: event)
        },
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      )
    else {
      return
    }

    eventTap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    isRunning = true
  }

  func stop() {
    guard isRunning else { return }
    if let tap = eventTap {
      CGEvent.tapEnable(tap: tap, enable: false)
    }
    if let source = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
    }
    eventTap = nil
    runLoopSource = nil
    isRunning = false
  }

  private func handle(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent
  ) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap = eventTap {
        CGEvent.tapEnable(tap: tap, enable: true)
      }
      return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown || type == .keyUp else {
      return Unmanaged.passUnretained(event)
    }

    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    guard keycode == Self.missionControlKeycode else {
      return Unmanaged.passUnretained(event)
    }

    if type == .keyDown {
      toggleABCThai()
    }
    return nil
  }

  private func toggleABCThai() {
    let now = ProcessInfo.processInfo.systemUptime
    if now - lastToggleAt < Self.debounceSeconds { return }
    lastToggleAt = now

    let list = TISCreateInputSourceList(nil, false).takeRetainedValue() as! [TISInputSource]
    let layouts = list.filter { isKeyboardLayout($0) }

    guard
      let abc = layouts.first(where: {
        let id = sourceID($0)
        return id.contains("keylayout.ABC") || id.contains("keylayout.US")
      }),
      let thai = layouts.first(where: { sourceID($0).contains("Thai") })
    else {
      return
    }

    let current = sourceID(TISCopyCurrentKeyboardInputSource().takeRetainedValue())
    if current.contains("Thai") {
      TISSelectInputSource(abc)
    } else {
      TISSelectInputSource(thai)
    }
  }

  private func sourceID(_ src: TISInputSource) -> String {
    Unmanaged<AnyObject>
      .fromOpaque(TISGetInputSourceProperty(src, kTISPropertyInputSourceID)!)
      .takeUnretainedValue() as! String
  }

  private func isKeyboardLayout(_ src: TISInputSource) -> Bool {
    let cf = TISGetInputSourceProperty(src, kTISPropertyInputSourceCategory)!
    let cat = Unmanaged<AnyObject>.fromOpaque(cf).takeUnretainedValue() as! String
    return cat == (kTISCategoryKeyboardInputSource as String)
  }
}
