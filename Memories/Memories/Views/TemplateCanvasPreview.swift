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
                    .padding(CardOverlayLayout.inset(for: size))
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
        VStack(alignment: editState.selectedPosition.horizontalAlignment, spacing: max(2, CardOverlayLayout.previewStackSpacing(for: size))) {
            if editState.visibilitySettings.showThemeIcon || shouldShowWeather {
                HStack(spacing: CardOverlayLayout.iconRowSpacing(for: size)) {
                    if editState.selectedPosition.isTrailing {
                        Spacer(minLength: 0)
                    }

                    if editState.visibilitySettings.showThemeIcon {
                        MemoriesTemplateIcon(
                            assetName: editState.selectedThemeIcon.assetName,
                            fallbackSystemName: editState.selectedThemeIcon.symbolName
                        )
                        .frame(
                            width: CardOverlayLayout.themeIconSize(for: size),
                            height: CardOverlayLayout.themeIconSize(for: size)
                        )
                    }

                    if shouldShowWeather, let symbolName = editState.selectedWeather.symbolName {
                        MemoriesTemplateIcon(
                            assetName: editState.selectedWeather.assetName,
                            fallbackSystemName: symbolName
                        )
                        .frame(
                            width: CardOverlayLayout.weatherIconSize(for: size),
                            height: CardOverlayLayout.weatherIconSize(for: size)
                        )
                    }
                }
            }

            if shouldShowLocation {
                metaLine(icon: .location, text: editState.locationText, size: size)
            }

            if shouldShowDate {
                metaLine(icon: .calendar, text: editState.displayDateText, size: size)
            }

            if shouldShowMainText {
                overlayText(editState.mainText, size: size, role: .main)
                    .padding(.top, max(2, CardOverlayLayout.base(for: size) * CardOverlayLayout.mainTopSpacingRatio))
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
        .frame(maxWidth: CardOverlayLayout.blockWidth(for: size), alignment: editState.selectedPosition.isTrailing ? .trailing : .leading)
    }

    private func overlayText(_ text: String, size: CGSize, role: PreviewTextRole) -> some View {
        Text(text)
            .font(font(for: role, size: size))
            .multilineTextAlignment(editState.selectedPosition.textAlignment)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func metaLine(icon: UtilityIconType, text: String, size: CGSize) -> some View {
        HStack(spacing: CardOverlayLayout.metaIconSize(for: size) * CardOverlayLayout.iconTextSpacingRatio) {
            if editState.selectedPosition.isTrailing {
                Spacer(minLength: 0)
            }

            MemoriesTemplateIcon(assetName: icon.assetName, fallbackSystemName: icon.fallbackSymbolName)
                .frame(
                    width: CardOverlayLayout.metaIconSize(for: size),
                    height: CardOverlayLayout.metaIconSize(for: size)
                )

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
        switch role {
        case .meta:
            return editState.selectedFontRole.font(size: CardOverlayLayout.fontSize(for: .meta, canvasSize: size), weight: .semibold)
        case .main:
            return editState.selectedFontRole.font(size: CardOverlayLayout.fontSize(for: .main, canvasSize: size), weight: .bold)
        case .sub:
            return editState.selectedFontRole.font(size: CardOverlayLayout.fontSize(for: .sub, canvasSize: size), weight: .medium)
        }
    }
}

private extension String {
    var trimmedForDisplay: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private typealias PreviewTextRole = CardOverlayTextRole

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
