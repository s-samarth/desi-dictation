import CoreGraphics
import Foundation

/// Where the menu-bar mic is, and where a callout pointing at it goes. Pure
/// geometry in AppKit coordinates (y grows upward), so desi-tests can check
/// it without a screen. The app supplies the frames (MenuBarPointer).
public enum MenuBarPlacement {
    public enum Visibility: Equatable {
        case visible
        /// A full menu bar on a notched MacBook pushes icons under the notch.
        case behindNotch
        /// Not on the screen at all (no frame yet, another display, hidden bar).
        case offScreen
    }

    /// `clearAreas`: the menu-bar strips either side of the notch
    /// (NSScreen.auxiliaryTopLeftArea / auxiliaryTopRightArea); empty when the
    /// screen has no notch.
    public static func visibility(icon: CGRect, screen: CGRect, clearAreas: [CGRect]) -> Visibility {
        // The centre, not the whole frame: the status window can poke a couple
        // of points above the screen's top edge.
        guard icon.width > 0, icon.height > 0,
              screen.contains(CGPoint(x: icon.midX, y: icon.midY)) else { return .offScreen }
        if clearAreas.isEmpty { return .visible }
        let clear = clearAreas.contains { icon.minX >= $0.minX - 1 && icon.maxX <= $0.maxX + 1 }
        return clear ? .visible : .behindNotch
    }

    /// A callout of `size` hanging just below the icon, kept `margin` inside
    /// the screen. `arrowX` is where its arrow sits, measured from the
    /// callout's left edge, so the arrow still points at the icon when the
    /// callout is pushed in from a screen edge.
    public static func callout(size: CGSize, below icon: CGRect, in screen: CGRect,
                               gap: CGFloat = 4, margin: CGFloat = 10) -> (frame: CGRect, arrowX: CGFloat) {
        let lowest = screen.minX + margin
        let highest = max(lowest, screen.maxX - margin - size.width)
        let x = min(max(icon.midX - size.width / 2, lowest), highest)
        let y = max(icon.minY - gap - size.height, screen.minY + margin)
        let corner: CGFloat = 22   // keep the arrow off the rounded corners
        let arrowX = min(max(icon.midX - x, corner), max(corner, size.width - corner))
        return (CGRect(x: x, y: y, width: size.width, height: size.height), arrowX)
    }

    /// Top-centre of the screen, under the menu bar: for when there's no icon
    /// to point at.
    public static func centered(size: CGSize, under screen: CGRect, menuBarHeight: CGFloat) -> CGRect {
        CGRect(x: screen.midX - size.width / 2,
               y: screen.maxY - menuBarHeight - 16 - size.height,
               width: size.width, height: size.height)
    }
}

/// Why the app is starting, which decides what it shows first.
public enum LaunchKind: Equatable {
    /// Never set up: the setup window.
    case firstRun
    /// Just relaunched by setup's Finish: show where the app lives, until dismissed.
    case afterSetup
    /// Started at login: stay silent.
    case atLogin
    /// Opened from Spotlight, Finder or the installer: point at the icon briefly.
    case byHand

    /// `loginItem`: the launch event said so. A launch in the first two
    /// minutes after boot counts too, in case the event doesn't.
    public static func of(onboarded: Bool, tourPending: Bool, loginItem: Bool,
                          uptime: TimeInterval) -> LaunchKind {
        if !onboarded { return .firstRun }
        if tourPending { return .afterSetup }
        if loginItem || uptime < 120 { return .atLogin }
        return .byHand
    }
}
