//
//  shadertypes.h
//  camera1
//
//  Created by Apple1 on 3/31/21.
//

#ifndef shadertypes_h
#define shadertypes_h
//#include "bool.h"
#include <simd/simd.h>

typedef struct{
    float iTime;
    simd_uint2 iRes;
    int ed,sh,bl,th,ng,yc;
    simd_float3 hsb;
    float offset;
}uniforms;


#endif /* shadertypes_h */
