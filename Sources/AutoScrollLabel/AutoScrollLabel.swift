import UIKit
import Combine

public final class AutoScrollLabel: UIView {
    private let labelSpacing: CGFloat
    private let pauseInterval: CGFloat
    private let scrollSpeed: CGFloat
    private let fadeRatio: Double
    private let font: UIFont
    private let textColor: UIColor

    private let changeTextSubject = PassthroughSubject<Void, Never>()
    private let layoutSubviewsSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isScrollEnabled = false
        scrollView.isUserInteractionEnabled = false
        return scrollView
    }()

    private lazy var firstLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.textAlignment = .center
        label.font = font
        label.textColor = textColor
        return label
    }()

    private lazy var secondLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.textAlignment = .center
        label.font = font
        label.textColor = textColor
        label.isHidden = true
        return label
    }()

    public init(
        labelSpacing: CGFloat = 30,
        pauseInterval: CGFloat = 2,
        scrollSpeed: CGFloat = 25,
        fadeRatio: Double = 0.1,
        font: UIFont = .systemFont(ofSize: 15),
        textColor: UIColor = .label
    ) {
        self.labelSpacing = labelSpacing
        self.pauseInterval = pauseInterval
        self.scrollSpeed = scrollSpeed
        self.fadeRatio = fadeRatio
        self.font = font
        self.textColor = textColor
        super.init(frame: .zero)
        addSubview(scrollView)
        scrollView.addSubview(firstLabel)
        scrollView.addSubview(secondLabel)

        changeTextSubject.combineLatest(
            layoutSubviewsSubject
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] (_, _) in
            self?.updateLayout()
            self?.setGradiantLayer()
            self?.scrollLabelIfNeeded()
        }.store(in: &cancellables)
    }

    public required init?(coder: NSCoder) {
        fatalError()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        layoutSubviewsSubject.send(())
    }

    private var scrollEnabled: Bool {
        scrollView.frame.width < firstLabel.intrinsicContentSize.width
    }

    private func updateLayout() {
        if scrollEnabled {
            firstLabel.frame = CGRect(
                origin: .zero,
                size: CGSize(
                    width: firstLabel.intrinsicContentSize.width,
                    height: self.bounds.height
                )
            )

            secondLabel.frame = CGRect(
                origin: CGPoint(
                    x: firstLabel.frame.maxX + labelSpacing,
                    y: 0
                ),
                size: CGSize(
                    width: secondLabel.intrinsicContentSize.width,
                    height: self.bounds.height
                )
            )

            scrollView.isScrollEnabled = true
            scrollView.contentSize = CGSize(width: secondLabel.frame.maxX, height: bounds.height)
            secondLabel.isHidden = false
        } else {
            firstLabel.frame = bounds
            scrollView.isScrollEnabled = false
            scrollView.contentSize = firstLabel.bounds.size
            secondLabel.isHidden = true
        }
    }

    private func setGradiantLayer() {
        if scrollEnabled {
            let transparent = UIColor(white: 0, alpha: 0).cgColor
            let opaque = UIColor(white: 0, alpha: 1).cgColor

            let maskLayer = CALayer()
            maskLayer.frame = bounds
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = bounds
            gradientLayer.colors = [transparent, opaque, opaque, transparent]
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
            gradientLayer.locations = [0.0, NSNumber(floatLiteral: fadeRatio), NSNumber(floatLiteral: 1.0 - fadeRatio), 1.0]
            maskLayer.addSublayer(gradientLayer)
            layer.mask = maskLayer
        } else {
            layer.mask = nil
        }
    }

    private var currentAnimator: UIViewPropertyAnimator?

    private func scrollLabelIfNeeded() {
        currentAnimator?.stopAnimation(true)
        currentAnimator = nil
        scrollView.contentOffset = .zero
        guard scrollEnabled else {
            return
        }
        let duration: Double = secondLabel.frame.maxX / scrollSpeed
        currentAnimator = UIViewPropertyAnimator.runningPropertyAnimator(withDuration: duration, delay: pauseInterval) { [weak self] in
            self?.scrollView.contentOffset = CGPoint(x: self?.secondLabel.frame.maxX ?? 0, y: 0)
        } completion: { [weak self] position in
            if position == .end {
                self?.scrollLabelIfNeeded()
            }
        }
        currentAnimator?.startAnimation()
    }

    public func change(text: String) {
        self.firstLabel.text = text
        self.secondLabel.text = text
        changeTextSubject.send(())
    }
}
