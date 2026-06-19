import Foundation

struct TemplateLoadResult {
    let templates: [Template]
    let errors: [TemplateRepositoryError]

    static let empty = TemplateLoadResult(templates: [], errors: [])
}

struct TemplateRepositoryError: Error, Identifiable {
    let id = UUID()
    let message: String
    let underlyingDescription: String?
}

protocol TemplateSource {
    func loadTemplates() -> TemplateLoadResult
}

struct TemplateRepository {
    private let sources: [TemplateSource]

    init(sources: [TemplateSource]) {
        self.sources = sources
    }

    static let bundled = TemplateRepository(
        sources: [
            BundleTemplateSource()
        ]
    )

    func loadTemplates() -> TemplateLoadResult {
        let sourceResults = sources.map { $0.loadTemplates() }
        return TemplateLoadResult(
            templates: sourceResults.flatMap(\.templates),
            errors: sourceResults.flatMap(\.errors)
        )
    }
}

struct BundleTemplateSource: TemplateSource {
    private let bundle: Bundle
    private let templateResourceNames: [String]
    private let searchSubdirectories: [String?]

    init(
        bundle: Bundle = .main,
        templateResourceNames: [String] = [
            "pet_lifelog_clean_001",
            "ticket_memory_portrait_001",
            "ticket_memory_landscape_001",
            "retro_film_001"
        ],
        searchSubdirectories: [String?] = ["Templates", "Resources/Templates", nil]
    ) {
        self.bundle = bundle
        self.templateResourceNames = templateResourceNames
        self.searchSubdirectories = searchSubdirectories
    }

    func loadTemplates() -> TemplateLoadResult {
        let urls = candidateURLs()

        guard !urls.isEmpty else {
            return TemplateLoadResult(
                templates: [],
                errors: [
                    TemplateRepositoryError(
                        message: "同梱テンプレートが見つかりませんでした。",
                        underlyingDescription: nil
                    )
                ]
            )
        }

        var templates: [Template] = []
        var errors: [TemplateRepositoryError] = []
        let decoder = JSONDecoder()

        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                templates.append(try decoder.decode(Template.self, from: data))
            } catch {
                errors.append(
                    TemplateRepositoryError(
                        message: "\(url.lastPathComponent) を読み込めませんでした。",
                        underlyingDescription: error.localizedDescription
                    )
                )
            }
        }

        return TemplateLoadResult(templates: templates, errors: errors)
    }

    private func candidateURLs() -> [URL] {
        var urls: [URL] = []

        for subdirectory in searchSubdirectories {
            if let discoveredURLs = bundle.urls(forResourcesWithExtension: "json", subdirectory: subdirectory) {
                urls.append(contentsOf: discoveredURLs.filter { url in
                    templateResourceNames.contains(url.deletingPathExtension().lastPathComponent)
                })
            }

            for resourceName in templateResourceNames {
                if let url = bundle.url(forResource: resourceName, withExtension: "json", subdirectory: subdirectory) {
                    urls.append(url)
                }
            }
        }

        var seenPaths: Set<String> = []
        return urls.filter { url in
            let inserted = seenPaths.insert(url.path).inserted
            return inserted
        }
    }
}
