import SwiftUI

enum LiquidGlassMetrics {
    static let menuWidth: CGFloat = 372
    static let onboardingSize = CGSize(width: 500, height: 540)
    static let trailingControlWidth: CGFloat = 116
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
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            LiquidGlassPanel(cornerRadius: cornerRadius) {
                VStack(alignment: .leading, spacing: rowSpacing) {
                    content()
                }
            }
        }
    }
}

struct LiquidGlassRow<Trailing: View>: View {
    let title: String
    var titleFont: Font = .callout
    var minHeight: CGFloat = 44
    var trailingWidth: CGFloat? = LiquidGlassMetrics.trailingControlWidth
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(titleFont)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

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
