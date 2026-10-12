import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "AppLogo" asset catalog image resource.
    static let appLogo = DeveloperToolsSupport.ImageResource(name: "AppLogo", bundle: resourceBundle)

    /// The "AppsLogo" asset catalog image resource.
    static let appsLogo = DeveloperToolsSupport.ImageResource(name: "AppsLogo", bundle: resourceBundle)

    /// The "CertsLogo" asset catalog image resource.
    static let certsLogo = DeveloperToolsSupport.ImageResource(name: "CertsLogo", bundle: resourceBundle)

    /// The "DownloadsLogo" asset catalog image resource.
    static let downloadsLogo = DeveloperToolsSupport.ImageResource(name: "DownloadsLogo", bundle: resourceBundle)

    /// The "EntitlementsLogo" asset catalog image resource.
    static let entitlementsLogo = DeveloperToolsSupport.ImageResource(name: "EntitlementsLogo", bundle: resourceBundle)

    /// The "LocationLogo" asset catalog image resource.
    static let locationLogo = DeveloperToolsSupport.ImageResource(name: "LocationLogo", bundle: resourceBundle)

    /// The "PairingLogo" asset catalog image resource.
    static let pairingLogo = DeveloperToolsSupport.ImageResource(name: "PairingLogo", bundle: resourceBundle)

    /// The "SideBySideLogo" asset catalog image resource.
    static let sideBySideLogo = DeveloperToolsSupport.ImageResource(name: "SideBySideLogo", bundle: resourceBundle)

}

