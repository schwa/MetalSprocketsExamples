#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface NSBundle (ShaderGraphShaders)
+ (NSBundle *)shaderGraphShaders;
@end
NS_ASSUME_NONNULL_END
#endif
