//
//  shader.metal
//  camera1
//
//  Created by Apple1 on 3/30/21.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "shadertypes.h"
using namespace metal;

constant uint2 iRes(750,1294);
constant float PI=3.141592653589793;


float4 ycbcr2rgb(float4 ycbcr){
    const float4x4 ycbcrToRGBTransform = float4x4(
        float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
        float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
        float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
        float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
    );
    return ycbcrToRGBTransform*ycbcr;
}

float4 getpixel(float2 uv,
                texture2d<float, access::sample> input0 [[texture(0)]],
                texture2d<float, access::sample> input1 [[texture(1)]]){
    constexpr sampler colsamp(mip_filter::linear,
                              mag_filter::linear,
                              min_filter::linear);
    return ycbcr2rgb(float4(input0.sample(colsamp,uv).r,input1.sample(colsamp,uv).rg,1));
}


float3 rgb2hsb(float3 c ){
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz),
                 float4(c.gb, K.xy),
                 step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r),
                 float4(c.r, p.yzx),
                 step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)),
                d / (q.x + e),
                q.x);
}

float3 hsb2rgb(float3 c){
    float3 rgb = clamp(abs(fmod(c.x*6.0+float3(0.0,4.0,2.0),
                             6.0)-3.0)-1.0,0.0,1.0 );
    rgb = rgb*rgb*(3.0-2.0*rgb);
    return c.z * mix(float3(1.0), rgb, c.y);
}

float map(float t,float a,float b,float c,float d){
    return c+(d-c)*(t-a)/(b-a);
}

float2x2 rot(float theta){
  return float2x2(cos(theta),-sin(theta),
                  sin(theta), cos(theta));
}

float2 rotuv(float2 uv,float theta){
    uv-=.5;
    uv=rot(theta)*uv;
    uv+=.5;
    return uv;
}

float3 conv(float2 uv,float3x3 k,
            texture2d<float, access::sample> input0 [[texture(0)]],
            texture2d<float, access::sample> input1 [[texture(1)]]){
    float3 s=float3(0.);
    for (int i=-1;i<=1;i++){
        for (int j=-1;j<=1;j++){
            s+=k[i+1][j+1]*getpixel(uv+float2(i,j)/float2(iRes),input0,input1).xyz;
        }
    }
    return s;
}







kernel void compute(texture2d<float, access::sample> in0 [[texture(0)]],
                    texture2d<float, access::sample> in1 [[texture(1)]],
                    texture2d<float, access::write> output [[texture(2)]],
                    constant uniforms &uni [[buffer(0)]],
                    uint2 id [[thread_position_in_grid]]){
    
    float2 uv=float2(id.y,id.x)/float2(uni.iRes.y,uni.iRes.x);
    uv.y=1-uv.y;
    
//    uv=rotuv(uv,uni.iTime);
    
    float3x3 edk=float3x3(-1,-1,-1, -1,+8,-1, -1,-1,-1);
    float3x3 shk=float3x3(+0,-1,+0, -1,+5,-1, +0,-1,+0);
    float3x3 gbk=float3x3(+1,+2,+1, +2,+4,+2, +1,+2,+1)/16.;
    
    
    uv=fmod(uv,1.);
    float3 col=float3(getpixel(uv,in0,in1).x,
                      getpixel(fmod(uv+float2(0,uni.offset),1),in0,in1).y,
                      getpixel(fmod(uv+2*float2(0,uni.offset),1),in0,in1).z);
    
    //convolution
    if     (uni.ed) col=conv(uv,edk,in0,in1);
    else if(uni.sh) col=conv(uv,shk,in0,in1);
    else if(uni.bl) col=conv(uv,gbk,in0,in1);
    
    if(uni.yc){
        constexpr sampler colsamp(mip_filter::linear,
                                  mag_filter::linear,
                                  min_filter::linear);
        col=in0.sample(colsamp,uv/float2(2,1)).xyz;
    }
    
    
    
    //HSB editing
    col=rgb2hsb(col);
    col.x=fmod(col.x+uni.hsb.x,1.);
    col.y=col.y*uni.hsb.y;
    col.z=col.z*uni.hsb.z;
    col=hsb2rgb(col);
    
    //image negative
    if (uni.ng) col=1.-col;
    //thresholding
    if (uni.th) col=floor(2.*col);


    float4 out(col,1);
    output.write(out, id);
}

