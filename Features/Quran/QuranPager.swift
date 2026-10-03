import SwiftUI
import UIKit

struct QuranPager: UIViewControllerRepresentable {
    let source: QuranSource
    @Binding var page: Int
    let onTap: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = NativeQuranPageController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        controller.dataSource = context.coordinator; controller.delegate = context.coordinator
        context.coordinator.controller = controller
        context.coordinator.present(page: page, source: source)
        return controller
    }
    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
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
            let value = PageController(page: page, onTap: { [weak self] in self?.parent.onTap() })
            pages[page] = value
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
            return pages[value.page + 1]
        }
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let value = viewController as? PageController, value.page > 1 else { return nil }
            return pages[value.page - 1]
        }
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let value = pageViewController.viewControllers?.first as? PageController, let source else { return }
            current = value.page; parent.page = value.page
            generation += 1
            prepareWindow(page: value.page, source: source)
        }
    }
}

// Hiding SwiftUI's navigation bar can disable UIKit's interactive pop gesture.
// Restore its native recognizer only while this reader is visible, then restore
// the previous delegate so other screens retain their navigation behaviour.
final class NativeQuranPageController: UIPageViewController, UIGestureRecognizerDelegate {
    private weak var previousDelegate: UIGestureRecognizerDelegate?
    private var previousEnabled = true
    private var installed = false
    private weak var installedEdge: UIGestureRecognizer?
    private weak var navigationOwner: UINavigationController?
    private weak var contentGesture: UIGestureRecognizer?
    private weak var previousContentDelegate: UIGestureRecognizerDelegate?
    private var previousContentEnabled = true
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
        if !installed { previousDelegate = edge.delegate; previousEnabled = edge.isEnabled; installed = true }
        installedEdge = edge
        navigationOwner = navigation
        edge.delegate = self; edge.isEnabled = navigation.viewControllers.count > 1
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), let content = navigation.interactiveContentPopGestureRecognizer {
            if contentGesture == nil { previousContentDelegate = content.delegate; previousContentEnabled = content.isEnabled }
            contentGesture = content; content.delegate = self; content.isEnabled = navigation.viewControllers.count > 1
        }
        #endif
        for scroll in scrollViews(view) {
            scroll.panGestureRecognizer.require(toFail: edge)
            if let contentGesture { scroll.panGestureRecognizer.require(toFail: contentGesture) }
        }
        print("[ReaderNavigation] native stack \(navigation.viewControllers.count), edge enabled \(edge.isEnabled)")
        (viewControllers?.first as? PageController)?.debugNavigation("stack \(navigation.viewControllers.count), edge \(edge.isEnabled)")
    }
    private func scrollViews(_ value: UIView) -> [UIScrollView] {
        value.subviews.flatMap { scrollViews($0) } + ((value as? UIScrollView).map { [$0] } ?? [])
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationOwner, navigationOwner.viewControllers.count > 1 else { return false }
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
        if installed, let edge = installedEdge {
            edge.delegate = previousDelegate; edge.isEnabled = previousEnabled; installed = false
            contentGesture?.delegate = previousContentDelegate; contentGesture?.isEnabled = previousContentEnabled
            contentGesture = nil
        }
    }
}

final class PageController: UIViewController {
    let page: Int
    private let onTap: () -> Void
    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    init(page: Int, onTap: @escaping () -> Void) { self.page = page; self.onTap = onTap; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("Programmatic page") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.accessibilityIdentifier = "quran.page.\(page)"
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "Page \(page)"
        imageView.accessibilityValue = "loading"
        for child in [imageView, spinner, errorLabel] { child.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(child) }
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor), imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor), imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor), spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24), errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
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
    func set(image: UIImage) { loadViewIfNeeded(); imageView.image = image; imageView.accessibilityValue = "ready"; spinner.stopAnimating(); errorLabel.text = nil }
    func show(error: String) { loadViewIfNeeded(); spinner.stopAnimating(); errorLabel.text = error }
}
