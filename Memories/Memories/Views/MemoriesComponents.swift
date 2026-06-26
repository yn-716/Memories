import SwiftUI

enum MemoriesLayoutMetrics {
    static let homeMaxWidth: CGFloat = 600
    static let editorMaxWidth: CGFloat = 720
    static let previewMaxWidth: CGFloat = 720
    static let purchaseMaxWidth: CGFloat = 620
    static let settingsMaxWidth: CGFloat = 680
    static let draftsMaxWidth: CGFloat = 680
    static let sheetMaxWidth: CGFloat = 540
}

struct MemoriesPrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            MemoriesPrimaryButtonLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }
}

struct MemoriesPrimaryButtonLabel: View {
    let title: String
    let systemImage: String?
    let gradientColors: [Color]
    let shadowColor: Color

    init(
        title: String,
        systemImage: String?,
        gradientColors: [Color] = [MemoriesTheme.accentDeep.opacity(0.94), MemoriesTheme.accent.opacity(0.82)],
        shadowColor: Color = MemoriesTheme.accentDeep.opacity(0.12)
    ) {
        self.title = title
        self.systemImage = systemImage
        self.gradientColors = gradientColors
        self.shadowColor = shadowColor
    }

    var body: some View {
        Label {
            Text(title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .layoutPriority(1)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.34), lineWidth: 1)
        }
        .shadow(color: shadowColor, radius: 10, y: 5)
    }
}

struct MemoriesSecondaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .layoutPriority(1)
            } icon: {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .foregroundStyle(MemoriesTheme.accentDeep)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(MemoriesTheme.border.opacity(0.86), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct MemoriesWatermarkOptionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.48)
    }

    private var foregroundColor: Color {
        isSelected ? MemoriesTheme.accentDeep : MemoriesTheme.textSub
    }

    private var backgroundColor: Color {
        isSelected ? MemoriesTheme.accent.opacity(0.18) : MemoriesTheme.card.opacity(0.48)
    }

    private var borderColor: Color {
        isSelected ? MemoriesTheme.accent.opacity(0.68) : MemoriesTheme.border.opacity(0.72)
    }
}

struct MemoriesGlassPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(.ultraThinMaterial)
            .background(MemoriesTheme.card.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(MemoriesTheme.border.opacity(0.9), lineWidth: 0.8)
            }
            .shadow(color: MemoriesTheme.accentDeep.opacity(0.05), radius: 12, y: 6)
    }
}

struct MemoriesPillTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(isSelected ? .white : MemoriesTheme.textSub)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? MemoriesTheme.accentDeep.opacity(0.88) : MemoriesTheme.card.opacity(0.42))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? .white.opacity(0.2) : MemoriesTheme.border.opacity(0.72), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct MemoriesToggleRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    @Binding var isOn: Bool

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        _isOn = isOn
    }

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.accentDeep)
                    .frame(width: 30, height: 30)
                    .background(MemoriesTheme.subBackground.opacity(0.82))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MemoriesTheme.textSub)
                }
            }

            Spacer()

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(MemoriesTheme.accentDeep)
        }
        .padding(12)
        .background(MemoriesTheme.card.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MemoriesTheme.border.opacity(0.65), lineWidth: 1)
        }
    }
}

struct MemoriesOptionChip: View {
    let title: String
    let systemImage: String?
    let swatchColor: Color?
    let isSelected: Bool
    let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        swatchColor: Color? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.swatchColor = swatchColor
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let swatchColor {
                    Circle()
                        .fill(swatchColor)
                        .frame(width: 14, height: 14)
                        .overlay {
                            Circle()
                                .stroke(MemoriesTheme.border.opacity(0.9), lineWidth: 1)
                        }
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                }

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? MemoriesTheme.accentDeep : MemoriesTheme.textMain)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? MemoriesTheme.accent.opacity(0.2) : MemoriesTheme.card.opacity(0.56))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? MemoriesTheme.accent.opacity(0.7) : MemoriesTheme.border.opacity(0.78), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct MemoriesGlassTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textSub)

            TextField(title, text: $text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MemoriesTheme.textMain)
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(MemoriesTheme.card.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MemoriesTheme.border.opacity(0.72), lineWidth: 1)
                }
        }
    }
}

struct MemoriesTemplateIcon: View {
    let assetName: String?
    let fallbackSystemName: String

    var body: some View {
        if let assetName {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: fallbackSystemName)
                .resizable()
                .scaledToFit()
        }
    }
}
