import UIKit

public enum ImageItem {
    case image(UIImage?)
    case url(URL, placeholder: UIImage?)
    case model(URL, placeholder: UIImage?, text: String?, id: String)
}

public protocol ImageItemType {
    var url: URL { get }
    var placeholder: UIImage? { get }
    var text: String? { get }
    var id: String { get }
}
