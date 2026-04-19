#import <Foundation/Foundation.h>

@interface PhosphorShaders_BundleFinder : NSObject
@end

@implementation PhosphorShaders_BundleFinder
@end

@implementation NSBundle (PhosphorShaders)

+ (NSBundle *)phosphorShadersBundle {
    static NSBundle *moduleBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *bundleName = @"MetalSprocketsExamples_PhosphorShaders";
        NSMutableArray<NSURL *> *candidates = [NSMutableArray array];

#if DEBUG
        NSDictionary *env = [[NSProcessInfo processInfo] environment];
        NSString *overridePath = env[@"PACKAGE_RESOURCE_BUNDLE_PATH"] ?: env[@"PACKAGE_RESOURCE_BUNDLE_URL"];
        if (overridePath) {
            [candidates addObject:[NSURL fileURLWithPath:overridePath]];
        }
#endif

        [candidates addObject:[NSBundle mainBundle].resourceURL];
        [candidates addObject:[[NSBundle bundleForClass:[PhosphorShaders_BundleFinder class]] resourceURL]];
        [candidates addObject:[NSBundle mainBundle].bundleURL];

        for (NSURL *candidate in candidates) {
            if (!candidate) continue;
            NSURL *bundlePath = [candidate URLByAppendingPathComponent:[bundleName stringByAppendingString:@".bundle"]];
            NSBundle *bundle = [NSBundle bundleWithURL:bundlePath];
            if (bundle) {
                moduleBundle = bundle;
                return;
            }
        }

        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"Unable to find bundle named %@", bundleName]
                                     userInfo:nil];
    });

    return moduleBundle;
}

@end
