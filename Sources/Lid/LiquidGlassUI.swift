import AppKit
import SwiftUI

enum LiquidGlassMetrics {
    static let menuWidth: CGFloat = 332
    static let settingsSize = CGSize(width: 388, height: 492)
    static let onboardingSize = CGSize(width: 468, height: 520)
    static let trailingControlWidth: CGFloat = 104
}

struct LiquidGlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var verticalPadding: CGFloat = 10
    var horizontalPadding: CGFloat = 12
    var alignment: Alignment = .leading
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, alignment: alignment)
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
    }
}

struct LiquidGlassSection<Content: View>: View {
    let title: String
    var cornerRadius: CGFloat = 20
    var rowSpacing: CGFloat = 4
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 4)

            LiquidGlassPanel(cornerRadius: cornerRadius, verticalPadding: 8, horizontalPadding: 12) {
                VStack(alignment: .leading, spacing: rowSpacing) {
                    content()
                }
            }
        }
    }
}

struct LiquidGlassRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var titleFont: Font = .callout
    var minHeight: CGFloat = 34
    var trailingWidth: CGFloat? = LiquidGlassMetrics.trailingControlWidth
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(titleFont)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 16)

            trailing()
                .fixedSize()
                .frame(width: trailingWidth, alignment: .trailing)
        }
        .frame(minHeight: minHeight)
    }
}

extension View {
    func liquidGlassSwitchStyle() -> some View {
        labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.accentColor)
    }
}

extension NSWindow {
    func configureLiquidGlassShell(title: String, size: CGSize, autosaveName: String? = nil, allowsMiniaturize: Bool = false) {
        self.title = title
        var mask: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]
        if allowsMiniaturize {
            mask.insert(.miniaturizable)
        }
        styleMask = mask
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        isReleasedWhenClosed = false
        contentMinSize = NSSize(width: size.width, height: size.height)
        setContentSize(NSSize(width: size.width, height: size.height))
        if let autosaveName {
            setFrameAutosaveName(autosaveName)
        }
    }
}
