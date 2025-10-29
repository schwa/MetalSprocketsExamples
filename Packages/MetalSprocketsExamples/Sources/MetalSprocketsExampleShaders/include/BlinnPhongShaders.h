#pragma once

#import "MetalSprocketsExampleShaders.h"

// long ambientTexture, long ambientSampler
struct BlinnPhongMaterialArgumentBuffer {
    ColorSourceArgumentBuffer ambient;
    ColorSourceArgumentBuffer diffuse;
    ColorSourceArgumentBuffer specular;
    float shininess;
};
