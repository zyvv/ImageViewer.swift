import UIKit
import Kingfisher

protocol ImageViewerControllerDelegate:class {
    func imageViewerDidClose(_ imageViewer: ImageViewerController)
    func imageViewerDidTapDetailLabel(_ imageViewer: ImageViewerController, imageItem: ImageItem)
    func imageViewerDidLongTap(_ imageViewer: ImageViewerController, imageItem: ImageItem)
}

class ImageViewerController:UIViewController, UIGestureRecognizerDelegate {
    
    var index:Int = 0
    weak var delegate:ImageViewerControllerDelegate?
    var imageItem:ImageItem!
    var animateOnDidAppear:Bool = false
    var sourceView:UIImageView?
    
    var backgroundView:UIView? {
        guard let _parent = parent as? ImageCarouselViewController
            else { return nil}
        return _parent.backgroundView
    }
    
    var navBar:UINavigationBar? {
        guard let _parent = parent as? ImageCarouselViewController
            else { return nil}
        return _parent.navBar
    }
    
    var theme:ImageViewerTheme = .light {
        didSet {
            if detailLabel != nil {
                detailLabel.textColor = theme.color
                detailView.backgroundColor = theme.tintColor
            }
        }
    }
    
    // MARK: Layout Constraints
    private var top:NSLayoutConstraint!
    private var leading:NSLayoutConstraint!
    private var trailing:NSLayoutConstraint!
    private var bottom:NSLayoutConstraint!
    
    private var labelHeight:NSLayoutConstraint!
    private var labelLeading:NSLayoutConstraint!
    private var labelTrailing:NSLayoutConstraint!
    private var labelBottom:NSLayoutConstraint!
    
    private var imageView:UIImageView!
    private var detailView:UIView!
    private var detailLabel:UILabel!
    private var scrollView:UIScrollView!
   
    private var lastLocation:CGPoint = .zero
    private var isAnimating:Bool = false
    private var maxZoomScale:CGFloat = 1.0
    
    init(sourceView:UIImageView? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.sourceView = sourceView
     
        modalPresentationStyle = .overFullScreen
        modalPresentationCapturesStatusBarAppearance = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        view.backgroundColor = .clear
        
        scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }
        view.addSubview(scrollView)
        scrollView.bindFrameToSuperview()
        scrollView.backgroundColor = .clear
        
        imageView = UIImageView(frame: .zero)
        scrollView.addSubview(imageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        top = imageView.topAnchor.constraint(equalTo: scrollView.topAnchor)
        leading = imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor)
        trailing = scrollView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor)
        bottom = scrollView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor)
        
        top.isActive = true
        leading.isActive = true
        trailing.isActive = true
        bottom.isActive = true
        
        detailView = UIView()
        detailView.backgroundColor = theme.tintColor
        view.addSubview(detailView)
        
        detailView.translatesAutoresizingMaskIntoConstraints = false
        labelHeight = detailView.heightAnchor.constraint(equalToConstant: 0)
        labelLeading = detailView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        labelTrailing = view.trailingAnchor.constraint(equalTo: detailView.trailingAnchor)
        if #available(iOS 11.0, *) {
            labelBottom = view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: detailView.safeAreaLayoutGuide.bottomAnchor)
        } else {
            labelBottom = detailView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        }
        
        labelHeight.isActive = true
        labelLeading.isActive = true
        labelTrailing.isActive = true
        labelBottom.isActive = true

        detailLabel = UILabel()
        detailLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        detailLabel.numberOfLines = 0
        detailLabel.textColor = theme.color
        detailView.addSubview(detailLabel)
        detailLabel.bindFrameToSuperview(top: 0, leading: 8, trailing: 8, bottom: 0)

        switch imageItem {
        case .image(let img):
            imageView.image = img
            imageView.layoutIfNeeded()
        case .url(let url, let placeholder):
            imageView.kf.setImage(with: url, placeholder: placeholder ?? sourceView?.image, options: nil, progressBlock: nil) { [weak self] result in
                self?.imageView.layoutIfNeeded()
            }
        case .model(let url, let placeholder, let text, _):
            imageView.kf.setImage(with: url, placeholder: placeholder ?? sourceView?.image, options: nil, progressBlock: nil) { [weak self] result in
                self?.imageView.layoutIfNeeded()
            }
            detailLabel.text = text
            let s = NSString(string: text ?? "")
            let sFrame = s.boundingRect(with: CGSize(width: UIScreen.main.bounds.width-16, height: 10000), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font : UIFont.preferredFont(forTextStyle: .footnote)], context: nil)
            labelHeight.constant = sFrame.height + 16
        default:
            break
        }
        
        addGestureRecognizers()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard animateOnDidAppear == true else {
            // skip animation
            return
        }
        animateOnDidAppear = false
        executeOpeningAnimation()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateConstraintsForSize(view.bounds.size)
        updateMinMaxZoomScaleForSize(view.bounds.size)
    }
    
    // MARK: Add Gesture Recognizers
    func addGestureRecognizers() {
        
        let panGesture = UIPanGestureRecognizer(
            target: self, action: #selector(didPan(_:)))
        panGesture.cancelsTouchesInView = false
        panGesture.delegate = self
        scrollView.addGestureRecognizer(panGesture)

        let pinchRecognizer = UITapGestureRecognizer(
            target: self, action: #selector(didPinch(_:)))
        pinchRecognizer.numberOfTapsRequired = 1
        pinchRecognizer.numberOfTouchesRequired = 2
        scrollView.addGestureRecognizer(pinchRecognizer)
        
        let singleTapGesture = UITapGestureRecognizer(
            target: self, action: #selector(didSingleTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.numberOfTouchesRequired = 1
        scrollView.addGestureRecognizer(singleTapGesture)
        
        let doubleTapRecognizer = UITapGestureRecognizer(
            target: self, action: #selector(didDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        scrollView.addGestureRecognizer(doubleTapRecognizer)
       
        singleTapGesture.require(toFail: doubleTapRecognizer)
        
        let longTapRecoginzer = UILongPressGestureRecognizer(target: self, action: #selector(didLongTap(_:)))
        longTapRecoginzer.minimumPressDuration = 0.25
//        longTapRecoginzer.numberOfTouchesRequired = 1
        scrollView.addGestureRecognizer(longTapRecoginzer)
        longTapRecoginzer.require(toFail: singleTapGesture)
        
        let labelTapRecoginzer = UITapGestureRecognizer(target: self, action: #selector(didLabelTap(_:)))
        labelTapRecoginzer.numberOfTapsRequired = 1
        labelTapRecoginzer.numberOfTouchesRequired = 1
        detailView.addGestureRecognizer(labelTapRecoginzer)
    }
    
    @objc
    func didPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard
            isAnimating == false,
            scrollView.zoomScale == scrollView.minimumZoomScale
            else { return }
        
        let container:UIView! = imageView
        if gestureRecognizer.state == .began {
            lastLocation = container.center
        }
        
        if gestureRecognizer.state != .cancelled {
            let translation: CGPoint = gestureRecognizer
                .translation(in: view)
            container.center = CGPoint(
                x: lastLocation.x + translation.x,
                y: lastLocation.y + translation.y)
        }

        let diffY = view.center.y - container.center.y
        backgroundView?.alpha = 1.0 - abs(diffY/view.center.y)
        detailView.alpha = backgroundView?.alpha == 1.0 ?  1.0 : 0.0
        if gestureRecognizer.state == .ended {
            if abs(diffY) > 60 {
                executeViewDismissalAnimation(diffY)
            } else {
                executeCancelAnimation()
            }
        }
    }
    
    @objc
    func didPinch(_ recognizer: UITapGestureRecognizer) {
        var newZoomScale = scrollView.zoomScale / 1.5
        newZoomScale = max(newZoomScale, scrollView.minimumZoomScale)
        scrollView.setZoomScale(newZoomScale, animated: true)
    }
    
    @objc
    func didSingleTap(_ recognizer: UITapGestureRecognizer) {
        
        let currentNavAlpha = self.navBar?.alpha ?? 0.0
        UIView.animate(withDuration: 0.15) {
            self.navBar?.alpha = currentNavAlpha > 0.5 ? 0.0 : 1.0
            self.detailView.alpha = currentNavAlpha > 0.5 ? 0.0 : 1.0
        }
    }
    
    @objc
    func didDoubleTap(_ recognizer:UITapGestureRecognizer) {
        let pointInView = recognizer.location(in: imageView)
        zoomInOrOut(at: pointInView)
    }
    
    @objc
    func didLongTap(_ recognizer: UILongPressGestureRecognizer) {
        self.delegate?.imageViewerDidLongTap(self, imageItem: imageItem)
    }
    
    @objc
    func didLabelTap(_ recognizer: UITapGestureRecognizer) {
        self.delegate?.imageViewerDidTapDetailLabel(self, imageItem: imageItem)
    }

    func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard scrollView.zoomScale == scrollView.minimumZoomScale,
            let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return false }

        let velocity = panGesture.velocity(in: scrollView)
        return abs(velocity.y) > abs(velocity.x)
    }
}

// MARK: Adjusting the dimensions
extension ImageViewerController {
    
    func updateMinMaxZoomScaleForSize(_ size: CGSize) {
        let minScale = min(
            size.width/imageView.bounds.width,
            size.height/imageView.bounds.height)
        let maxScale = max(
            (size.width + 1.0) / imageView.bounds.width,
            (size.height + 1.0) / imageView.bounds.height)
        
        scrollView.minimumZoomScale = minScale
        scrollView.zoomScale = minScale
        maxZoomScale = maxScale
        scrollView.maximumZoomScale = maxZoomScale * 1.1
    }
    
    
    func zoomInOrOut(at point:CGPoint) {
        let newZoomScale = scrollView.zoomScale == scrollView.minimumZoomScale
            ? maxZoomScale : scrollView.minimumZoomScale
        let size = scrollView.bounds.size
        let w = size.width / newZoomScale
        let h = size.height / newZoomScale
        let x = point.x - (w * 0.5)
        let y = point.y - (h * 0.5)
        let rect = CGRect(x: x, y: y, width: w, height: h)
        scrollView.zoom(to: rect, animated: true)
    }
    
    func updateConstraintsForSize(_ size: CGSize) {
        let yOffset = max(0, (size.height - imageView.frame.height) / 2)
        top.constant = yOffset
        bottom.constant = yOffset
        
        let xOffset = max(0, (size.width - imageView.frame.width) / 2)
        leading.constant = xOffset
        trailing.constant = xOffset
        view.layoutIfNeeded()
    }

}

// MARK: Animation Related stuff
extension ImageViewerController {
    
    private func executeOpeningAnimation() {
        
        guard let _sourceView = sourceView else { return }
        
        let dummyImageView:UIImageView = UIImageView(
            frame: _sourceView.frameRelativeToWindow())
        dummyImageView.clipsToBounds = true
        dummyImageView.contentMode = .scaleAspectFill
        dummyImageView.alpha = 1.0
        dummyImageView.image = imageView.image
        view.addSubview(dummyImageView)
        view.sendSubviewToBack(dummyImageView)
        
        _sourceView.alpha = 1.0
        imageView.alpha = 0.0
        detailView.alpha = 0.0
        backgroundView?.alpha = 0.0
        isAnimating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {[weak self] in
            guard let _self = self else { return }
            UIView.animate(withDuration: 0.237, animations: {
                dummyImageView.contentMode = .scaleAspectFit
                dummyImageView.frame = _self.view.frame
                _self.backgroundView?.alpha = 1.0
                _sourceView.alpha = 0.0
            }) { _ in
                _self.imageView.alpha = 1.0
                _self.detailView.alpha = 1.0
                dummyImageView.removeFromSuperview()
                _self.isAnimating = false
            }
        }
    }
    
    private func executeCancelAnimation() {
        self.isAnimating = true
        UIView.animate(
            withDuration: 0.237,
            animations: {
                self.imageView.center = self.view.center
                self.backgroundView?.alpha = 1.0
        }) {[weak self] _ in
            self?.isAnimating = false
        }
    }
    
    private func executeViewDismissalAnimation(_ diffY:CGFloat) {
        isAnimating = true
        
        let dummyImageView:UIImageView = UIImageView(frame: imageView.frame)
        dummyImageView.image = imageView.image
        dummyImageView.clipsToBounds = false
        dummyImageView.contentMode = .scaleAspectFill
        view.addSubview(dummyImageView)
        imageView.isHidden = true
        
        let exitFrame:CGRect = { () -> CGRect in
            guard let _sourceFrame = self.sourceView?.frameRelativeToWindow()
                else {
                    var imageViewFrame = self.imageView.frame
                    if diffY > 0 {
                        imageViewFrame.origin.y = -imageViewFrame.size.height
                    } else {
                        imageViewFrame.origin.y = view.frame.size.height
                    }
                    return imageViewFrame
            }
            return _sourceFrame
        }()
        
        UIView.animate(withDuration: 0.237, animations: {
            dummyImageView.frame = exitFrame
            dummyImageView.clipsToBounds = true
            self.backgroundView?.alpha = 0.0
            self.navBar?.alpha = 0.0
        }) { _ in
            self.dismiss(animated: false) {
                dummyImageView.removeFromSuperview()
                self.delegate?.imageViewerDidClose(self)
            }
        }
    }
}

extension ImageViewerController:UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateConstraintsForSize(view.bounds.size)
    }
}


// MARK: Shortcuts
extension ImageViewerController {
    
    static func create(
        index: Int,
        imageItem:ImageItem,
        sourceView:UIImageView?,
        delegate:ImageViewerControllerDelegate) -> ImageViewerController {
        
        let newVC = ImageViewerController()
        newVC.index = index
        newVC.imageItem = imageItem
        newVC.sourceView = sourceView
        newVC.delegate = delegate
        return newVC
    }
}
