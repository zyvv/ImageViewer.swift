import UIKit

public enum ImageItem {
    case image(UIImage?)
    case url(URL, placeholder: UIImage?)
    case model(URL, placeholder: UIImage?, text: String?, id: String)
}

public protocol ImageItemType {
    var imageItemUrl: URL { get }
    var imageItemPlaceholder: UIImage? { get }
    var imageItemText: String? { get }
    var imageItemId: String { get }
}
