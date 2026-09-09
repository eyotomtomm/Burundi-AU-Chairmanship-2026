import SwiftUI
import WidgetKit

// MARK: - Model

/// One featured item, as the API hands it over.
struct FeatureItem: Decodable {
    let title: String?
    let category: String?
    let image: String?
    let isFeatured: Bool?

    enum CodingKeys: String, CodingKey {
        case title, category, image
        case isFeatured = "is_featured"
    }
}

struct FeatureEntry: TimelineEntry {
    let date: Date
    let title: String
    let category: String
    let image: UIImage?
    let isFeatured: Bool
    /// True when the network failed and this is the last thing we managed to show.
    let isStale: Bool

    static let placeholder = FeatureEntry(
        date: Date(),
        title: "Burundi's Chairmanship of the African Union",
        category: "Diplomacy",
        image: nil,
        isFeatured: true,
        isStale: false
    )
}

// MARK: - Loading

enum FeatureLoader {
    /// Production only. A widget runs outside the app and has no access to the
    /// dev host, so pointing it at localhost would leave it permanently blank.
    static let endpoint = URL(string: "https://burundi4africa.com/api/widget/feature/")!

    private static let cacheKey = "b4africa.widget.lastFeature"

    static func fetch() async -> FeatureEntry {
        do {
            var request = URLRequest(url: endpoint)
            request.timeoutInterval = 12
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let item = try JSONDecoder().decode(FeatureItem.self, from: data)
            guard let title = item.title, !title.isEmpty else { throw URLError(.zeroByteResource) }

            let image = await loadImage(item.image)
            let entry = FeatureEntry(
                date: Date(),
                title: title,
                category: item.category ?? "",
                image: image,
                isFeatured: item.isFeatured ?? false,
                isStale: false
            )
            cache(title: title, category: entry.category)
            return entry
        } catch {
            // Offline or the server is down: show the last good headline rather
            // than an empty tile, and mark it so the timestamp reads honestly.
            return cached() ?? FeatureEntry(
                date: Date(),
                title: "Be 4 Africa",
                category: "",
                image: nil,
                isFeatured: false,
                isStale: true
            )
        }
    }

    private static func loadImage(_ urlString: String?) async -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    private static func cache(title: String, category: String) {
        UserDefaults.standard.set(["title": title, "category": category], forKey: cacheKey)
    }

    private static func cached() -> FeatureEntry? {
        guard let stored = UserDefaults.standard.dictionary(forKey: cacheKey),
              let title = stored["title"] as? String else { return nil }
        return FeatureEntry(
            date: Date(),
            title: title,
            category: stored["category"] as? String ?? "",
            image: nil,
            isFeatured: false,
            isStale: true
        )
    }
}

// MARK: - Timeline

struct FeatureProvider: TimelineProvider {
    func placeholder(in context: Context) -> FeatureEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (FeatureEntry) -> Void) {
        // The gallery preview must not wait on the network.
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { completion(await FeatureLoader.fetch()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FeatureEntry>) -> Void) {
        Task {
            let entry = await FeatureLoader.fetch()
            // Refresh hourly. The system throttles widgets hard, so asking for
            // anything tighter just gets ignored.
            let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

// MARK: - Views

private enum Brand {
    static let green = Color(red: 0.251, green: 0.596, blue: 0.263)   // #409843
    static let greenDeep = Color(red: 0.180, green: 0.447, blue: 0.192) // #2E7231
    static let gold = Color(red: 0.988, green: 0.820, blue: 0.086)     // #FCD116
    static let goldInk = Color(red: 0.290, green: 0.243, blue: 0.0)    // #4A3E00
}

struct B4AfricaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FeatureEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background
            content
        }
        .widgetBackgroundCompat()
    }

    @ViewBuilder
    private var background: some View {
        if let image = entry.image {
            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.05), .black.opacity(0.78)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        } else {
            LinearGradient(
                colors: [Brand.greenDeep, Brand.green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)

            if entry.isFeatured {
                Text("FEATURED")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.7)
                    .foregroundStyle(Brand.goldInk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Brand.gold, in: Capsule())
            } else if !entry.category.isEmpty {
                Text(entry.category.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.7)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Text(entry.title)
                .font(.system(size: family == .systemSmall ? 13 : 16, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(family == .systemSmall ? 3 : 3)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if entry.isStale {
                Text("Offline")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(14)
    }
}

// Widgets must declare a background container on iOS 17+, but the modifier
// does not exist earlier — this keeps one source building for both.
private extension View {
    @ViewBuilder
    func widgetBackgroundCompat() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) { Color.clear }
        } else {
            self
        }
    }
}

// MARK: - Widget

struct B4AfricaWidget: Widget {
    let kind = "B4AfricaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FeatureProvider()) { entry in
            B4AfricaWidgetView(entry: entry)
        }
        .configurationDisplayName("Be 4 Africa")
        .description("The featured story from the AU Chairmanship.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct B4AfricaWidgetBundle: WidgetBundle {
    var body: some Widget { B4AfricaWidget() }
}
