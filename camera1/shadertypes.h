//
//  shadertypes.h
//  camera1
//
//  Created by Apple1 on 3/31/21.
//

#ifndef shadertypes_h
#define shadertypes_h
#include <simd/simd.h>

typedef struct{
    float iTime;
    simd_uint2 iRes;
    int frameCount;
    float dt;
    int ed,sh,bl,th,ng,yc,ex,rd;
    simd_float3 hsb;
    float offset;
}uniforms;


#endif /* shadertypes_h */
