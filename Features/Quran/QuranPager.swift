import SwiftUI
import UIKit

struct QuranPager: UIViewControllerRepresentable {
    let source: QuranSource
    @Binding var page: Int
    let onTap: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        controller.dataSource = context.coordinator; controller.delegate = context.coordinator
        context.coordinator.controller = controller
        context.coordinator.present(page: page, source: source)
        return controller
    }
    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
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
    func set(image: UIImage) { loadViewIfNeeded(); imageView.image = image; spinner.stopAnimating(); errorLabel.text = nil }
    func show(error: String) { loadViewIfNeeded(); spinner.stopAnimating(); errorLabel.text = error }
}
