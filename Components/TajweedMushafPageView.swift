import WebKit
import UIKit

/// A local rendering surface only. Navigation, sessions and audio remain native.
@MainActor final class TajweedMushafPageView: UIView, WKNavigationDelegate {
    private final class Bridge: NSObject, WKScriptMessageHandler {
        weak var owner: TajweedMushafPageView?
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) { owner?.receive(message) }
    }
    private let bridge = Bridge()
    private var web: WKWebView!
    private let margin = QuranMarginOverlay()
    private let audio = QuranAudioOverlay()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let retry = UIButton(type: .system)
    private var task: Task<Void, Never>?
    private var resource: TajweedMushafResourceService.Resource?
    private var regions: [QuranVerseRegion] = []
    private var annotations = QuranPageAnnotations()
    private let page: Int
    private let onTap: () -> Void
    private let onVerse: (Int) -> Void
    private static let catalog = QuranCatalog()
    init(page: Int, onTap: @escaping () -> Void, onVerse: @escaping (Int) -> Void) {
        self.page = page; self.onTap = onTap; self.onVerse = onVerse
        super.init(frame: .zero)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(bridge, name: "mushaf")
        bridge.owner = self
        web = WKWebView(frame: .zero, configuration: configuration)
        web.navigationDelegate = self; web.isOpaque = false; web.backgroundColor = .white
        web.scrollView.isScrollEnabled = false; web.scrollView.bounces = false
        web.accessibilityIdentifier = "quran.tajweed.page.\(page)"; web.accessibilityValue = "loading"
        retry.setTitle("Impossible de charger cette page. Réessayer", for: .normal)
        retry.titleLabel?.numberOfLines = 0; retry.addTarget(self, action: #selector(loadPage), for: .touchUpInside)
        retry.isHidden = true
        for child in [web!, margin, audio, spinner, retry] { child.translatesAutoresizingMaskIntoConstraints = false; addSubview(child) }
        for child in [web!, margin, audio] { NSLayoutConstraint.activate([child.leadingAnchor.constraint(equalTo: leadingAnchor), child.trailingAnchor.constraint(equalTo: trailingAnchor), child.topAnchor.constraint(equalTo: topAnchor), child.bottomAnchor.constraint(equalTo: bottomAnchor)]) }
        NSLayoutConstraint.activate([spinner.centerXAnchor.constraint(equalTo: centerXAnchor), spinner.centerYAnchor.constraint(equalTo: centerYAnchor), retry.centerXAnchor.constraint(equalTo: centerXAnchor), retry.centerYAnchor.constraint(equalTo: centerYAnchor), retry.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -32), retry.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)])
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:))); hold.minimumPressDuration = 0.45
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped)); tap.require(toFail: hold)
        web.addGestureRecognizer(hold); web.addGestureRecognizer(tap)
        loadPage()
    }
    required init?(coder: NSCoder) { fatalError("Programmatic renderer") }
    deinit { task?.cancel() }
    @objc private func tapped() { onTap() }
    @objc private func held(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: web)
        web.evaluateJavaScript("window.selectAt(\(point.x),\(point.y))")
    }
    @objc private func loadPage() {
        task?.cancel(); retry.isHidden = true; spinner.startAnimating()
        task = Task { [weak self, page] in
            do {
                let value = try await TajweedMushafResourceService.shared.page(page)
                guard !Task.isCancelled, let self else { return }
                resource = value
                web.loadFileURL(value.directory.appendingPathComponent("page.html"), allowingReadAccessTo: value.directory.deletingLastPathComponent())
            } catch { guard !Task.isCancelled else { return }; self?.showError(error) }
        }
    }
    func set(annotations: QuranPageAnnotations) { self.annotations = annotations; refreshOverlays() }
    private func refreshOverlays() {
        let size = CGSize(width: TajweedMushafHTML.width, height: TajweedMushafHTML.height)
        margin.configure(regions: regions, annotations: annotations, imageSize: size)
        audio.configure(regions: regions, imageSize: size, verseID: annotations.audioVerseID, color: annotations.audioColor)
    }
    private func receive(_ message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let body = message.body as? [String: Any], body["page"] as? Int == page, let kind = body["kind"] as? String else { return }
        if kind == "verse", let key = body["value"] as? String, resource?.page.verseKeys.contains(key) == true,
           let id = TajweedMushafPage.verseID(key, catalog: Self.catalog) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(); onVerse(id)
        } else if kind == "ready", let rows = body["value"] as? [[String: Any]] {
            regions = rows.compactMap { row in
                guard let key = row["key"] as? String, resource?.page.verseKeys.contains(key) == true,
                      let id = TajweedMushafPage.verseID(key, catalog: Self.catalog), let line = row["line"] as? Int,
                      let x = row["x"] as? Double, let y = row["y"] as? Double,
                      let width = row["width"] as? Double, let height = row["height"] as? Double,
                      x.isFinite, y.isFinite, width > 0, height > 0 else { return nil }
                return QuranVerseRegion(id: id, ayah: Int(key.split(separator: ":").last!)!, line: line, x: x, y: y, width: width, height: height)
            }
            spinner.stopAnimating(); retry.isHidden = true; web.accessibilityValue = "ready"; refreshOverlays()
        } else if kind == "error" { showError(URLError(.cannotDecodeContentData)) }
    }
    private func showError(_ error: Error) { spinner.stopAnimating(); retry.isHidden = false; print("[QCF] page \(page): \(error)") }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { showError(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { showError(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { showError(URLError(.cannotLoadFromNetwork)) }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Font requests are subresources. No website or external links may navigate here.
        decisionHandler(navigationAction.request.url?.isFileURL == true ? .allow : .cancel)
    }
}
