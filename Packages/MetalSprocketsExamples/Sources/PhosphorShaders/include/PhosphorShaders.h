#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSBundle (PhosphorShaders)
+ (NSBundle *)phosphorShadersBundle;
@end

NS_ASSUME_NONNULL_END

#endif
