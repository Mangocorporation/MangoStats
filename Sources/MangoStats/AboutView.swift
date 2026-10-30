import AppKit
import MangoStatsKit
import SwiftUI

/// The About tab: what MangoStats is, its version and links, and the other
/// MangoCorp apps (S-045).
struct AboutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metric.sectionGap) {
                header
                HStack(alignment: .top, spacing: Metric.cardGap) {
                    aboutCard
                    creditsCard
                }
                VStack(alignment: .leading, spacing: Metric.cardGap) {
                    Text("More from MangoCorp").kitType(.sectionTitle).foregroundStyle(Ink.text)
                    ForEach(MangoApp.others) { app in OtherAppCard(app: app) }
                }
            }
            .padding(.horizontal, Metric.windowMargin)
            .padding(.top, Metric.windowTop)
            .padding(.bottom, Metric.windowMargin)
            .frame(maxWidth: Metric.aboutWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.top)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Metric.sectionGap - 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: Metric.aboutIcon, height: Metric.aboutIcon)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Metric.iconGap) {
                Text("MangoStats").kitType(.pageTitle).foregroundStyle(Ink.text)
                Text(Self.version).kitType(.mono).foregroundStyle(Ink.secondary)
                Text("An honest Mac system monitor in the menu bar.")
                    .kitType(.pageSubtitle).foregroundStyle(Ink.body)
                HStack(spacing: Metric.cardGap - 6) {
                    Button(model.updater.available.map { "Install \($0)…" } ?? "Check for Updates…") { model.updater.check() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!model.updater.enabled || !model.updater.canCheck)
                        .help("Look for a newer version of MangoStats")
                    link("Website", Links.website)
                    link("GitHub", Links.repository)
                    link("What's New", Links.releases)
                }
                .padding(.top, Metric.iconGap)
            }
        }
    }

    private func link(_ title: String, _ url: URL) -> some View {
        Button(L10n.t(title)) { NSWorkspace.shared.open(url) }
            .buttonStyle(SecondaryButtonStyle())
            .help(url.absoluteString)
    }

    private var aboutCard: some View {
        KitCard(height: nil, fitsContent: true, padding: Metric.insightPadding) {
            Eyebrow(text: "About")
            Text("MangoStats shows what your Mac is doing and says what's worth a look, in plain words: CPU, GPU, memory, storage, network, temperatures, fan, battery, and every process, with history, alerts, and a Network tab that finds where a connection problem is.")
                .kitType(.body).foregroundStyle(Ink.body).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Metric.cardGap - 4)
            Text("Everything stays on this Mac. No accounts, no analytics, no ads.")
                .kitType(.body).foregroundStyle(Ink.body)
                .padding(.top, Metric.cardGap - 4)
        }
    }

    private var creditsCard: some View {
        KitCard(height: nil, fitsContent: true, padding: Metric.insightPadding) {
            Eyebrow(text: "Credits")
            VStack(alignment: .leading, spacing: Metric.iconGap) {
                credit("Made by", "MangoCorp")
                credit("License", "MIT, open source")
                credit("Updates", "Sparkle (MIT)")
                credit("Device makers", "IEEE OUI registry")
            }
            .padding(.top, Metric.cardGap - 4)
            Button("View the license") { NSWorkspace.shared.open(Links.license) }
                .buttonStyle(LinkButtonStyle())
                .padding(.top, Metric.cardGap - 4)
        }
        .frame(maxWidth: Metric.creditsWidth)
    }

    private func credit(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.t(label)).kitType(.statLabel).foregroundStyle(Ink.secondary)
            Spacer(minLength: Metric.cardGap)
            Text(value).kitType(.mono).foregroundStyle(Ink.body)
        }
    }

    /// "Version 1.2 (202610301600)".
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? ""
        return L10n.f("Version %@", short) + (build.isEmpty ? "" : " (\(build))")
    }

    enum Links {
        static let website = URL(string: "https://mangocorporation.github.io/MangoStats/")!
        static let repository = URL(string: "https://github.com/Mangocorporation/MangoStats")!
        static let releases = URL(string: "https://github.com/Mangocorporation/MangoStats/releases")!
        static let license = URL(string: "https://github.com/Mangocorporation/MangoStats/blob/main/LICENSE")!
    }
}

/// Another MangoCorp app, for About › More from MangoCorp. Add a row to `others`
/// and an icon named "<Name>-icon.png" in Resources/.
struct MangoApp: Identifiable {
    let name: String
    let bundleID: String
    let tagline: String
    let detail: String
    let website: URL
    var id: String { bundleID }

    static let others = [
        MangoApp(name: "MangoMemory", bundleID: "com.mangocorp.mangomemory",
                 tagline: "Know what your Mac's memory is really doing.",
                 detail: "Memory pressure at a glance, the five apps using the most RAM, and a real file-cache clear. Free and open source.",
                 website: URL(string: "https://mangocorporation.github.io/MangoMemory/")!),
    ]

    /// Where it's installed, if it is.
    var installedURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }

    /// The installed app's icon, or the one bundled with MangoStats.
    var icon: NSImage {
        if let url = installedURL { return NSWorkspace.shared.icon(forFile: url.path) }
        return Bundle.main.url(forResource: "\(name)-icon", withExtension: "png").flatMap(NSImage.init(contentsOf:))
            ?? NSApp.applicationIconImage
    }
}

private struct OtherAppCard: View {
    let app: MangoApp

    var body: some View {
        let installed = app.installedURL
        KitCard(height: nil, fitsContent: true) {
            HStack(alignment: .center, spacing: Metric.cardGap + 4) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: Metric.otherAppIcon, height: Metric.otherAppIcon)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Metric.iconGap - 2) {
                    HStack(alignment: .firstTextBaseline, spacing: Metric.cardGap - 6) {
                        Text(app.name).kitType(.sectionTitle).foregroundStyle(Ink.text)
                        if installed != nil { KitPill(text: "installed") }
                    }
                    Text(L10n.t(app.tagline)).kitType(.body).foregroundStyle(Ink.body)
                    Text(L10n.t(app.detail)).kitType(.footer).foregroundStyle(Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Metric.cardGap)
                if let installed {
                    Button("Open \(app.name)") { NSWorkspace.shared.openApplication(at: installed, configuration: .init()) }
                        .buttonStyle(PrimaryButtonStyle())
                        .help("Open \(app.name)")
                } else {
                    Button("Get \(app.name)") { NSWorkspace.shared.open(app.website) }
                        .buttonStyle(PrimaryButtonStyle())
                        .help("Open \(app.name)'s website to download it")
                }
                Button("Website") { NSWorkspace.shared.open(app.website) }
                    .buttonStyle(SecondaryButtonStyle())
                    .help(app.website.absoluteString)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.name). \(app.tagline) \(installed == nil ? "Not installed" : "Installed")")
    }
}
