import SwiftUI

struct TemplateSelectionView: View {
    private let repository: TemplateRepository

    @State private var loadState: TemplateSelectionLoadState = .loading

    init(repository: TemplateRepository = .bundled) {
        self.repository = repository
    }

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                ProgressView()
                    .tint(MemoriesTheme.accentDeep)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let templates, let errors):
                templateList(templates: templates, errors: errors)
            case .failed(let errors):
                TemplateErrorView(errors: errors)
            }
        }
        .background(MemoriesTheme.background.ignoresSafeArea())
        .navigationTitle("ライフログカード")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadTemplates()
        }
    }

    private func templateList(templates: [Template], errors: [TemplateRepositoryError]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TemplateCategoryHeader()

                if !errors.isEmpty {
                    TemplateWarningView(errors: errors)
                }

                ForEach(templates.filter { $0.category == "petLifelog" }) { template in
                    NavigationLink {
                        EditorView(template: template)
                    } label: {
                        TemplateCardView(template: template)
                    }
                }
            }
            .padding(20)
        }
    }

    private func loadTemplates() {
        let result = repository.loadTemplates()

        if result.templates.isEmpty, !result.errors.isEmpty {
            loadState = .failed(result.errors)
        } else {
            loadState = .loaded(result.templates, result.errors)
        }
    }
}

private enum TemplateSelectionLoadState {
    case loading
    case loaded([Template], [TemplateRepositoryError])
    case failed([TemplateRepositoryError])
}

private struct TemplateCategoryHeader: View {
    private let chips = ["Pet Lifelog", "Clean", "Soft", "Minimal"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pet Lifelog")
                .font(.title3.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textMain)

            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MemoriesTheme.accentDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MemoriesTheme.subBackground)
                        .clipShape(RoundedRectangle(cornerRadius: MemoriesTheme.controlRadius))
                }
            }
        }
    }
}

private struct TemplateCardView: View {
    let template: Template

    var body: some View {
        HStack(spacing: 16) {
            TemplateCanvasPreview(
                template: template,
                editState: template.previewEditState,
                media: nil,
                aspectRatio: template.defaultAspectRatio.value
            )
            .frame(width: 82)
            .clipShape(RoundedRectangle(cornerRadius: MemoriesTheme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: MemoriesTheme.cardRadius)
                    .stroke(MemoriesTheme.border, lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(MemoriesTheme.textMain)
                Text("\(template.categoryDisplayName) / \(template.overlayStyle.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(MemoriesTheme.textSub)
                Text(template.supportedAspectRatios.map(\.displayName).joined(separator: "  "))
                    .font(.caption)
                    .foregroundStyle(MemoriesTheme.textSub)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textSub)
        }
        .padding(14)
        .background(MemoriesTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: MemoriesTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: MemoriesTheme.cardRadius)
                .stroke(MemoriesTheme.border, lineWidth: 1)
        }
    }
}

private struct TemplateWarningView: View {
    let errors: [TemplateRepositoryError]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(errors) { error in
                Text(error.message)
                    .font(.footnote)
                    .foregroundStyle(MemoriesTheme.textSub)
            }
        }
        .padding(12)
        .background(MemoriesTheme.subBackground)
        .clipShape(RoundedRectangle(cornerRadius: MemoriesTheme.cardRadius))
    }
}

private struct TemplateErrorView: View {
    let errors: [TemplateRepositoryError]

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(MemoriesTheme.accentDeep)
            ForEach(errors) { error in
                Text(error.message)
                    .font(.subheadline)
                    .foregroundStyle(MemoriesTheme.textSub)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
    }
}

#Preview {
    NavigationStack {
        TemplateSelectionView()
    }
}
