import SwiftUI
import DesiDictationKit

/// The overlay's after-dictation row: "Didn't catch that", an error, or
/// "Copied — press ⌘V". Same capsule as the live rows, so it reads as the
/// end of the same dictation, not a new popup (FM#31).
struct OverlayNoticeRow: View {
    let notice: DictationNotice

    var body: some View {
        Image(systemName: icon)
            .foregroundStyle(tint)
            .font(.system(size: 13, weight: .semibold))
        Text(notice.message)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: OverlayView.width - 60, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var icon: String {
        switch notice.kind {
        case .problem: return "exclamationmark.triangle.fill"
        case .copied: return "doc.on.clipboard"
        }
    }

    private var tint: Color {
        switch notice.kind {
        case .problem: return .orange
        case .copied: return .accentColor
        }
    }
}
