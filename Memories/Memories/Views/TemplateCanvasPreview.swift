import SwiftUI
import UIKit

struct TemplateCanvasPreview: View {
    let template: Template
    let editState: CardEditState
    let photoImage: UIImage?
    let aspectRatio: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                photoPlaceholder

                overlayContent(size: size)
                    .padding(min(size.width, size.height) * 0.065)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: editState.selectedPosition.alignment)
            }
            .clipShape(RoundedRectangle(cornerRadius: MemoriesTheme.cardRadius))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    @ViewBuilder
    private var photoPlaceholder: some View {
        if let photoImage {
            Image(uiImage: photoImage)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    Color(hex: template.overlayStyle.photoPlaceholderStartColor),
                    Color(hex: template.overlayStyle.photoPlaceholderEndColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 46, weight: .regular))
                    .foregroundStyle(.white.opacity(0.36))
            }
        }
    }

    private func overlayContent(size: CGSize) -> some View {
        VStack(alignment: editState.selectedPosition.horizontalAlignment, spacing: max(3, size.width * 0.012)) {
            if editState.visibilitySettings.showThemeIcon || shouldShowWeather {
                HStack(spacing: max(5, size.width * 0.018)) {
                    if editState.selectedPosition.isTrailing {
                        Spacer(minLength: 0)
                    }

                    if editState.visibilitySettings.showThemeIcon {
                        Image(systemName: editState.selectedThemeIcon.symbolName)
                            .font(.system(size: max(15, size.width * 0.06), weight: .medium))
                    }

                    if shouldShowWeather, let symbolName = editState.selectedWeather.symbolName {
                        Image(systemName: symbolName)
                            .font(.system(size: max(15, size.width * 0.058), weight: .medium))
                    }
                }
            }

            if shouldShowLocation {
                metaLine(systemImage: "mappin", text: editState.locationText, size: size)
            }

            if shouldShowDate {
                overlayText(editState.displayDateText, size: size, role: .meta)
            }

            if shouldShowMainText {
                overlayText(editState.mainText, size: size, role: .main)
                    .padding(.top, max(2, size.width * 0.01))
            }

            if shouldShowSubText {
                overlayText(editState.subText, size: size, role: .sub)
            }

        }
        .foregroundStyle(editState.selectedTextColor.color)
        .shadow(
            color: .black.opacity(editState.selectedTextColor == .white ? 0.28 : 0.1),
            radius: editState.selectedTextColor == .white ? 5 : 2,
            y: 1
        )
        .frame(maxWidth: size.width * 0.58, alignment: editState.selectedPosition.isTrailing ? .trailing : .leading)
    }

    private func overlayText(_ text: String, size: CGSize, role: PreviewTextRole) -> some View {
        Text(text)
            .font(font(for: role, size: size))
            .multilineTextAlignment(editState.selectedPosition.textAlignment)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func metaLine(systemImage: String, text: String, size: CGSize) -> some View {
        HStack(spacing: max(3, size.width * 0.01)) {
            if editState.selectedPosition.isTrailing {
                Spacer(minLength: 0)
            }

            Image(systemName: systemImage)
                .font(font(for: .meta, size: size))

            overlayText(text, size: size, role: .meta)
        }
    }

    private var shouldShowWeather: Bool {
        editState.visibilitySettings.showWeather && editState.selectedWeather != .none
    }

    private var shouldShowLocation: Bool {
        editState.visibilitySettings.showLocation && !editState.locationText.trimmedForDisplay.isEmpty
    }

    private var shouldShowDate: Bool {
        editState.visibilitySettings.showDate && !editState.displayDateText.trimmedForDisplay.isEmpty
    }

    private var shouldShowMainText: Bool {
        editState.visibilitySettings.showMainText && !editState.mainText.trimmedForDisplay.isEmpty
    }

    private var shouldShowSubText: Bool {
        editState.visibilitySettings.showSubText && !editState.subText.trimmedForDisplay.isEmpty
    }

    private func font(for role: PreviewTextRole, size: CGSize) -> Font {
        let base = min(size.width, size.height)

        switch role {
        case .meta:
            return editState.selectedFontRole.font(size: max(9, base * 0.035), weight: .medium)
        case .main:
            return editState.selectedFontRole.font(size: max(20, base * 0.085), weight: .semibold)
        case .sub:
            return editState.selectedFontRole.font(size: max(11, base * 0.043), weight: .regular)
        }
    }
}

private extension String {
    var trimmedForDisplay: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum PreviewTextRole {
    case meta
    case main
    case sub
}

#Preview {
    let template = Template(
        id: "preview",
        name: "Pet Lifelog Clean",
        category: "petLifelog",
        supportedAspectRatios: [.fourByFive, .square, .nineBySixteen],
        defaultLayout: .bottomLeft,
        overlayStyle: OverlayStyle(
            name: "Clean",
            defaultTextColor: .white,
            defaultFontRole: .clean,
            photoPlaceholderStartColor: "#BFD8EA",
            photoPlaceholderEndColor: "#8FB7D9",
            addsSoftShadow: true
        ),
        textFieldDefinitions: []
    )

    return TemplateCanvasPreview(
        template: template,
        editState: template.previewEditState,
        photoImage: nil,
        aspectRatio: CardAspectRatio.fourByFive.value
    )
    .frame(width: 240)
    .padding()
    .background(MemoriesTheme.background)
}
