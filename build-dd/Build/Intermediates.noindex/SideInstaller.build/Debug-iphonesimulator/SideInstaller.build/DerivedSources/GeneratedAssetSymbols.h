#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "AppLogo" asset catalog image resource.
static NSString * const ACImageNameAppLogo AC_SWIFT_PRIVATE = @"AppLogo";

/// The "AppsLogo" asset catalog image resource.
static NSString * const ACImageNameAppsLogo AC_SWIFT_PRIVATE = @"AppsLogo";

/// The "CertsLogo" asset catalog image resource.
static NSString * const ACImageNameCertsLogo AC_SWIFT_PRIVATE = @"CertsLogo";

/// The "DownloadsLogo" asset catalog image resource.
static NSString * const ACImageNameDownloadsLogo AC_SWIFT_PRIVATE = @"DownloadsLogo";

/// The "EntitlementsLogo" asset catalog image resource.
static NSString * const ACImageNameEntitlementsLogo AC_SWIFT_PRIVATE = @"EntitlementsLogo";

/// The "LocationLogo" asset catalog image resource.
static NSString * const ACImageNameLocationLogo AC_SWIFT_PRIVATE = @"LocationLogo";

/// The "PairingLogo" asset catalog image resource.
static NSString * const ACImageNamePairingLogo AC_SWIFT_PRIVATE = @"PairingLogo";

/// The "SideBySideLogo" asset catalog image resource.
static NSString * const ACImageNameSideBySideLogo AC_SWIFT_PRIVATE = @"SideBySideLogo";

#undef AC_SWIFT_PRIVATE
