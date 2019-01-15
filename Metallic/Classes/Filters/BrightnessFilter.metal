//
//  BrightnessFilter.metal
//  Metallic
//
//  Created by Chaitanya Pandit on 14/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void Brightness(
                       texture2d<float, access::write> outTexture [[texture(0)]],
                       texture2d<float, access::read> inTexture [[texture(1)]],
                       device float *brightness [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]])
{
    const float4 inColor = inTexture.read(gid);
    const float4 outColor(inColor.rgb+float3(*brightness),inColor.a);
    outTexture.write(outColor, gid);
}

