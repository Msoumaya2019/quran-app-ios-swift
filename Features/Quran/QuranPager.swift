import SwiftUI
import UIKit

struct QuranPager: UIViewControllerRepresentable {
    let source: QuranSource
    @Binding var page: Int
    let onTap: () -> Void
    var annotations = QuranPageAnnotations()
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = NativeQuranPageController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        controller.dataSource = context.coordinator; controller.delegate = context.coordinator
        context.coordinator.controller = controller
        context.coordinator.present(page: page, source: source)
        return controller
    }
    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        let annotationsChanged = context.coordinator.parent.annotations != annotations
        context.coordinator.parent = self
        if annotationsChanged { context.coordinator.pages.values.forEach { $0.set(annotations: annotations) } }
        (controller as? NativeQuranPageController)?.refreshNativeBack()
        if context.coordinator.source != source || context.coordinator.current != page {
            context.coordinator.present(page: page, source: source)
        }
    }
    @MainActor final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: QuranPager
        weak var controller: UIPageViewController?
        var source: QuranSource?
        var current = 0
        var pages: [Int: PageController] = [:]
        private var generation = 0
        init(_ parent: QuranPager) { self.parent = parent }
        func present(page: Int, source: QuranSource) {
            generation += 1
            if self.source != source { pages.removeAll() }
            self.source = source; current = page
            let current = pageController(page)
            controller?.setViewControllers([current], direction: .forward, animated: false)
            prepareWindow(page: page, source: source)
        }
        private func pageController(_ page: Int) -> PageController {
            if let existing = pages[page] { return existing }
            let value = PageController(page: page, source: source ?? parent.source, onTap: { [weak self] in self?.parent.onTap() })
            value.set(annotations: parent.annotations)
            pages[page] = value
            // UIKit may ask for the next candidate before didFinishAnimating
            // moves our three-page window. Never report a false end of Mushaf.
            if let requestedSource = source {
                Task { [weak self, weak value] in
                    do {
                        let image = try await QuranPageCache.shared.image(source: requestedSource, page: page)
                        guard self?.source == requestedSource else { return }
                        value?.set(image: image)
                    } catch {
                        guard self?.source == requestedSource else { return }
                        value?.show(error: "La page n’a pas pu être chargée. Réessaie depuis le menu Plus.")
                    }
                }
            }
            return value
        }
        private func prepareWindow(page: Int, source: QuranSource) {
            let token = generation
            let range = max(1, page - 1)...min(source.pageCount, page + 1)
            pages = pages.filter { range.contains($0.key) }
            for number in range { _ = pageController(number) }
            Task {
                await QuranPageCache.shared.setWindow(source: source, page: page)
                for number in [page, page - 1, page + 1] where range.contains(number) {
                    do {
                        let image = try await QuranPageCache.shared.image(source: source, page: number)
                        guard generation == token else { return }
                        pages[number]?.set(image: image)
                    } catch {
                        guard generation == token else { return }
                        pages[number]?.show(error: "La page n’a pas pu être chargée. Réessaie depuis le menu Plus.")
                    }
                }
            }
        }
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let value = viewController as? PageController, let source, value.page < source.pageCount else { return nil }
            // Arabic page order: a swipe towards the right advances the Mushaf.
            return pageController(value.page + 1)
        }
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let value = viewController as? PageController, value.page > 1 else { return nil }
            return pageController(value.page - 1)
        }
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let value = pageViewController.viewControllers?.first as? PageController, let source else { return }
            // UIKit can return a controller it retained outside our latest window.
            // Keep the visible instance authoritative for subsequent overlay updates.
            pages[value.page] = value
            value.set(annotations: parent.annotations)
            current = value.page; parent.page = value.page
            generation += 1
            prepareWindow(page: value.page, source: source)
        }
    }
}

// Keep UIKit's native edge recognizer and give it priority over page pans.
// iOS 26's content-wide back recognizer is limited to the leading edge here
// so ordinary Arabic page swipes continue to work inside a pushed reader.
final class NativeQuranPageController: UIPageViewController, UIGestureRecognizerDelegate {
    private weak var navigationOwner: UINavigationController?
    private weak var contentGesture: UIGestureRecognizer?
    private weak var previousContentDelegate: UIGestureRecognizerDelegate?
    private var previousContentEnabled = true
    private lazy var readerBackGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleReaderBack(_:)))
        gesture.delegate = self
        return gesture
    }()
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshNativeBack()
    }
    func refreshNativeBack() {
        DispatchQueue.main.async { [weak self] in self?.enableNativeBack() }
    }
    private func enableNativeBack() {
        let controllers = navigationControllers(view.window?.rootViewController)
        let containingStack = controllers.first { $0.viewControllers.count > 1 && view.isDescendant(of: $0.view) }
        guard let navigation = containingStack ?? navigationController ?? controllers.first(where: { view.isDescendant(of: $0.view) }),
              let edge = navigation.interactivePopGestureRecognizer else {
            (viewControllers?.first as? PageController)?.debugNavigation("no native navigation controller")
            return
        }
        navigationOwner = navigation
        if readerBackGesture.view == nil { view.addGestureRecognizer(readerBackGesture) }
        readerBackGesture.isEnabled = navigation.viewControllers.count > 1
        edge.require(toFail: readerBackGesture)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), let content = navigation.interactiveContentPopGestureRecognizer {
            if contentGesture == nil { previousContentDelegate = content.delegate; previousContentEnabled = content.isEnabled }
            contentGesture = content; content.delegate = self
            content.isEnabled = navigation.viewControllers.count > 1 && !navigation.isNavigationBarHidden
        }
        #endif
        for scroll in scrollViews(view) {
            scroll.panGestureRecognizer.require(toFail: readerBackGesture)
            scroll.panGestureRecognizer.require(toFail: edge)
            if let contentGesture { scroll.panGestureRecognizer.require(toFail: contentGesture) }
        }
        print("[ReaderNavigation] native stack \(navigation.viewControllers.count), edge enabled \(edge.isEnabled)")
        (viewControllers?.first as? PageController)?.debugNavigation("stack \(navigation.viewControllers.count), edge \(edge.isEnabled)")
    }
    @objc private func handleReaderBack(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .ended, let navigationOwner else { return }
        let distance = gesture.translation(in: view).x
        let speed = gesture.velocity(in: view).x
        if distance > view.bounds.width * 0.18 || speed > 500 {
            navigationOwner.popViewController(animated: true)
        }
    }
    private func scrollViews(_ value: UIView) -> [UIScrollView] {
        value.subviews.flatMap { scrollViews($0) } + ((value as? UIScrollView).map { [$0] } ?? [])
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationOwner, navigationOwner.viewControllers.count > 1 else { return false }
        if gestureRecognizer === readerBackGesture {
            let translation = readerBackGesture.translation(in: view)
            let start = readerBackGesture.location(in: view).x - translation.x
            return start <= 24 && translation.x > abs(translation.y)
        }
        guard !navigationOwner.isNavigationBarHidden else { return false }
        let location = gestureRecognizer.location(in: navigationOwner.view)
        let translation = (gestureRecognizer as? UIPanGestureRecognizer)?.translation(in: navigationOwner.view) ?? .zero
        return location.x - translation.x <= 24 && translation.x >= 0
    }
    private func navigationControllers(_ value: UIViewController?) -> [UINavigationController] {
        guard let value else { return [] }
        if let tabs = value as? UITabBarController { return navigationControllers(tabs.selectedViewController) }
        var result = value.children.flatMap { navigationControllers($0) }
        if let navigation = value as? UINavigationController { result.append(navigation) }
        return result
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        contentGesture?.delegate = previousContentDelegate; contentGesture?.isEnabled = previousContentEnabled
        contentGesture = nil
    }
}

final class PageController: UIViewController {
    let page: Int
    private let onTap: () -> Void
    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let margin = QuranMarginOverlay()
    private let regions: [QuranVerseRegion]
    private var annotations = QuranPageAnnotations()
    private static let catalog = QuranCatalog()
    init(page: Int, source: QuranSource = .medina, onTap: @escaping () -> Void) {
        self.page = page; self.onTap = onTap
        regions = QuranMarginGeometry.regions(source: source, page: page, catalog: Self.catalog)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Programmatic page") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.accessibilityIdentifier = "quran.page.\(page)"
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "Page \(page)"
        imageView.accessibilityValue = "loading"
        for child in [imageView, spinner, errorLabel, margin] { child.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(child) }
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor), imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor), imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor), spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24), errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            margin.leadingAnchor.constraint(equalTo: view.leadingAnchor), margin.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            margin.topAnchor.constraint(equalTo: view.topAnchor), margin.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        errorLabel.numberOfLines = 0; errorLabel.textAlignment = .center; errorLabel.font = .preferredFont(forTextStyle: .body)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        spinner.startAnimating()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let edge = navigationController?.interactivePopGestureRecognizer,
           let pager = parent as? UIPageViewController {
            for scroll in pager.view.subviews.compactMap({ $0 as? UIScrollView }) { scroll.panGestureRecognizer.require(toFail: edge) }
        }
    }
    @objc private func tapped() { onTap() }
    func debugNavigation(_ status: String) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-authenticated") { imageView.accessibilityLabel = "Page \(page) · \(status)" }
        #endif
    }
    func set(image: UIImage) { loadViewIfNeeded(); imageView.image = image; imageView.accessibilityValue = "ready"; spinner.stopAnimating(); errorLabel.text = nil; refreshMargin() }
    func set(annotations: QuranPageAnnotations) {
        guard self.annotations != annotations else { return }
        self.annotations = annotations
        if isViewLoaded { refreshMargin() }
    }
    private func refreshMargin() {
        margin.configure(regions: regions, annotations: annotations, imageSize: imageView.image?.size ?? .zero)
    }
    func show(error: String) { loadViewIfNeeded(); spinner.stopAnimating(); errorLabel.text = error }
}
