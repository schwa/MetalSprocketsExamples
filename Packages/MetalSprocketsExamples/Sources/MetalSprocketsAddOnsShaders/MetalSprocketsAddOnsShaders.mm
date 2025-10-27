#import <Foundation/Foundation.h>

@interface MetalSprocketsAddOns_BundleFinder : NSObject
@end

@implementation MetalSprocketsAddOns_BundleFinder
@end

@implementation NSBundle (MetalSprocketsAddOns)

+ (NSBundle *)metalSprocketsAddOnsShadersBundle {
    static NSBundle *moduleBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *bundleName = @"MetalSprocketsExamples_MetalSprocketsAddOnsShaders";
        //NSString *bundleName = @"MetalSprocketsAddOns_MetalSprocketsAddOnsShaders";
        NSMutableArray<NSURL *> *overrides = [NSMutableArray array];
#if DEBUG
        // The 'PACKAGE_RESOURCE_BUNDLE_PATH' name is preferred since the expected value is a path.
        // The check for 'PACKAGE_RESOURCE_BUNDLE_URL' will be removed when all clients have switched over.
        NSDictionary *env = [[NSProcessInfo processInfo] environment];
        NSString *overridePath = env[@"PACKAGE_RESOURCE_BUNDLE_PATH"] ?: env[@"PACKAGE_RESOURCE_BUNDLE_URL"];
        if (overridePath) {
            [overrides addObject:[NSURL fileURLWithPath:overridePath]];
        }
#endif
        NSArray<NSURL *> *candidates = [overrides arrayByAddingObjectsFromArray:@[
            [NSBundle mainBundle].resourceURL,
            [[NSBundle bundleForClass:[MetalSprocketsAddOns_BundleFinder class]] resourceURL],
            [NSBundle mainBundle].bundleURL
        ]];
        for (NSURL *candidate in candidates) {
            if (candidate) {
                NSURL *bundlePath = [candidate URLByAppendingPathComponent:[bundleName stringByAppendingString:@".bundle"]];
                NSBundle *bundle = [NSBundle bundleWithURL:bundlePath];
                if (bundle) {
                    moduleBundle = bundle;
                    return;
                }
            }
        }
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat: @"Unable to find bundle named %@", bundleName] userInfo:nil];
    });

    return moduleBundle;
}

@end
