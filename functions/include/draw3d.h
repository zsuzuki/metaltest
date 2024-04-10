//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#import "camera.h"
#import <MetalKit/MetalKit.h>
#include <simd/vector_types.h>

@interface Draw3D : NSObject

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view
                                   shaderlib:(nonnull id<MTLLibrary>)library;
- (void)render:(nullable id<MTLRenderCommandEncoder>)renderEncoder
        camera:(nonnull CameraData *)camera;
- (void)drawLine:(simd_float3)from to:(simd_float3)to color:(simd_float4)color;
- (void)drawTriangle:(simd_float3)p0 p1:(simd_float3)p1 p2:(simd_float3)p2 color:(simd_float4)color;
- (void)drawPlane:(simd_float3)p0
               p1:(simd_float3)p1
               p2:(simd_float3)p2
               p3:(simd_float3)p3
            color:(simd_float4)color;

@end
