import CoreGraphics
import DesiDictationKit

/// The first-run pointer: is the menu-bar mic on screen, and where does the
/// callout pointing at it go (MenuBarPlacement, LaunchKind).
func runMenuBarTests() {
    T.begin("Menu-bar pointer")
    // A 1512×982 MacBook screen with a notch from x 663 to 849, menu bar 37 pt.
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let left = CGRect(x: 0, y: 945, width: 663, height: 37)
    let right = CGRect(x: 849, y: 945, width: 663, height: 37)
    let icon = { (x: CGFloat) in CGRect(x: x, y: 945, width: 30, height: 37) }

    T.equal(MenuBarPlacement.visibility(icon: icon(1200), screen: screen, clearAreas: [left, right]),
            .visible, "icon right of the notch is visible")
    T.equal(MenuBarPlacement.visibility(icon: icon(700), screen: screen, clearAreas: [left, right]),
            .behindNotch, "icon under the notch is hidden")
    T.equal(MenuBarPlacement.visibility(icon: icon(840), screen: screen, clearAreas: [left, right]),
            .behindNotch, "icon half under the notch counts as hidden")
    T.equal(MenuBarPlacement.visibility(icon: icon(700), screen: screen, clearAreas: []),
            .visible, "no notch: anywhere on the bar is visible")
    // Measured live on a 1080p display: the icon's window ends 2 pt above the screen.
    T.equal(MenuBarPlacement.visibility(icon: CGRect(x: 1390, y: 1049, width: 29, height: 33),
                                        screen: CGRect(x: 0, y: 0, width: 1920, height: 1080), clearAreas: []),
            .visible, "icon poking above the top edge is visible")
    T.equal(MenuBarPlacement.visibility(icon: .zero, screen: screen, clearAreas: []),
            .offScreen, "no frame yet is off screen")
    T.equal(MenuBarPlacement.visibility(icon: icon(1600), screen: screen, clearAreas: [left, right]),
            .offScreen, "icon on another display is off screen here")

    let size = CGSize(width: 360, height: 180)
    let middle = MenuBarPlacement.callout(size: size, below: icon(1000), in: screen)
    T.equal(middle.frame.midX, 1015, "callout centres under the icon")
    T.equal(middle.arrowX, 180, "arrow in the middle when centred")
    T.equal(middle.frame.maxY, 941, "callout hangs just below the menu bar")

    let edge = MenuBarPlacement.callout(size: size, below: icon(1440), in: screen)
    T.equal(edge.frame.maxX, 1502, "callout stays 10 pt inside the right edge")
    T.equal(edge.frame.minX + edge.arrowX, 1455, "pushed-in callout still points at the icon")

    let corner = MenuBarPlacement.callout(size: size, below: icon(1490), in: screen)
    T.equal(corner.arrowX, 338, "arrow stays off the rounded corner")

    let notice = MenuBarPlacement.centered(size: size, under: screen, menuBarHeight: 37)
    T.equal(notice.midX, 756, "notice centres on the screen")
    T.equal(notice.maxY, 929, "notice sits under the menu bar")

    T.equal(LaunchKind.of(onboarded: false, tourPending: false, loginItem: true, uptime: 30),
            .firstRun, "not set up: setup window, even at login")
    T.equal(LaunchKind.of(onboarded: true, tourPending: true, loginItem: false, uptime: 9_000),
            .afterSetup, "Finish's relaunch shows the tour")
    T.equal(LaunchKind.of(onboarded: true, tourPending: false, loginItem: true, uptime: 9_000),
            .atLogin, "login item stays silent")
    T.equal(LaunchKind.of(onboarded: true, tourPending: false, loginItem: false, uptime: 40),
            .atLogin, "just after boot counts as login")
    T.equal(LaunchKind.of(onboarded: true, tourPending: false, loginItem: false, uptime: 9_000),
            .byHand, "opened by hand points at the icon")
}
