import UIKit

public enum ImageItem {
    case image(UIImage?)
    case url(URL, placeholder: UIImage?)
    case model(URL, placeholder: UIImage?, text: String?, id: String)
}
