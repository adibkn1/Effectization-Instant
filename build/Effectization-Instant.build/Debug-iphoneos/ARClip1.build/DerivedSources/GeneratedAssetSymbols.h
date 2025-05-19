#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "arrow" asset catalog image resource.
static NSString * const ACImageNameArrow AC_SWIFT_PRIVATE = @"arrow";

/// The "noInternetClip" asset catalog image resource.
static NSString * const ACImageNameNoInternetClip AC_SWIFT_PRIVATE = @"noInternetClip";

#undef AC_SWIFT_PRIVATE
