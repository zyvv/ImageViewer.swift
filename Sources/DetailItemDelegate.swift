public protocol DetailItemDelegate:class {
    func imageViewer(_ imageViewer: ImageCarouselViewController, didTapDetailLabel imageItem:ImageItem)
    
    func imageViewer(_ imageViewer: ImageCarouselViewController, didLongTapImageItem imageItem:ImageItem)
}
