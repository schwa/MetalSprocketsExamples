#if defined(METAL) || defined(__OBJC__)

#pragma once

#if defined(METAL) || defined(__OBJC__)
#import "MetalSprocketsAddOnsShaders.h"
#endif

#import "Lighting.h"
#import "Support.h"

// long ambientTexture, long ambientSampler
struct BlinnPhongMaterialArgumentBuffer {
    ColorSourceArgumentBuffer ambient;
    ColorSourceArgumentBuffer diffuse;
    ColorSourceArgumentBuffer specular;
    float shininess;
};

#endif
