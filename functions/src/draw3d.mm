//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#import "draw3d.h"
#import "camera.h"
#include "dsemaphore.h"
#include "shader_def.h"
#import <Metal/Metal.h>
#include <arm_neon.h>
#include <list>
#include <memory>
#include <simd/simd.h>

@interface Draw3D ()
@end

@implementation Draw3D
{
  id<MTLDevice>  device_;
  MTLPixelFormat colorFormat_;
  MTLPixelFormat depthFormat_;
  NSUInteger     sampleCount_;
  CGFloat        contentScale_;
  NSUInteger     pageIndex_;

  id<MTLRenderPipelineState> pipelineState_;
  id<MTLBuffer>              uniformBuffer_[3];
  id<MTLBuffer>              vertices_[3];
  id<MTLBuffer>              verticesPlane_[3];
  NSUInteger                 nbPrimitives_;
  NSUInteger                 nbPlanes_;

  SimpleLock primLock_;
  SimpleLock planeLock_;
}

//
- (void)initializePipeline:(id<MTLLibrary>)library
{
  NSError *error        = nil;
  auto     pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];

  auto vertexFunction   = [library newFunctionWithName:@"primVert3d"];
  auto fragmentFunction = [library newFunctionWithName:@"primFrag3d"];

  // text
  pipelineDesc.label                        = @"PipelinePrim3D";
  pipelineDesc.rasterSampleCount            = sampleCount_;
  pipelineDesc.vertexFunction               = vertexFunction;
  pipelineDesc.fragmentFunction             = fragmentFunction;
  pipelineDesc.vertexDescriptor             = nil;
  pipelineDesc.depthAttachmentPixelFormat   = depthFormat_;
  pipelineDesc.stencilAttachmentPixelFormat = depthFormat_;

  auto colorAttachment                      = pipelineDesc.colorAttachments[0];
  colorAttachment.pixelFormat               = colorFormat_;
  colorAttachment.blendingEnabled           = YES;
  colorAttachment.sourceRGBBlendFactor      = MTLBlendFactorSourceAlpha;
  colorAttachment.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
  colorAttachment.rgbBlendOperation         = MTLBlendOperationAdd;

  pipelineState_ = [device_ newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];

  [pipelineDesc release];
}

//
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view
                                   shaderlib:(nonnull id<MTLLibrary>)library
{
  [super init];

  device_       = view.device;
  colorFormat_  = view.colorPixelFormat;
  depthFormat_  = view.depthStencilPixelFormat;
  sampleCount_  = view.sampleCount;
  contentScale_ = [[NSScreen mainScreen] backingScaleFactor];
  pageIndex_    = 0;
  nbPrimitives_ = 0;
  nbPlanes_     = 0;
  [self initializePipeline:library];

  for (int i = 0; i < 3; i++)
  {
    uniformBuffer_[i] = [device_ newBufferWithLength:sizeof(Uniforms)
                                             options:MTLResourceStorageModeShared];
    vertices_[i]      = [device_ newBufferWithLength:sizeof(VertexDataPrim3D) * 4 * 30000
                                        options:MTLResourceStorageModeShared];
    verticesPlane_[i] = [device_ newBufferWithLength:sizeof(VertexDataPrim3D) * 3 * 100000
                                             options:MTLResourceStorageModeShared];
  }

  return self;
}

//
- (void)dealloc
{
  for (int i = 0; i < 3; i++)
  {
    [uniformBuffer_[i] release];
    [vertices_[i] release];
    [verticesPlane_[i] release];
  }
  [pipelineState_ release];
  [super dealloc];
}

//
- (void)drawLine:(simd_float3)from to:(simd_float3)to color:(simd_float4)color
{
  primLock_.lock();
  auto  vtx   = vertices_[pageIndex_];
  auto *vtx3d = (VertexDataPrim3D *)vtx.contents + nbPrimitives_;

  nbPrimitives_ += 2;
  primLock_.unlock();

  auto col16        = vcvt_f16_f32(color);
  vtx3d[0].position = from;
  vtx3d[0].color    = col16;
  vtx3d[1].position = to;
  vtx3d[1].color    = col16;
}

//
- (void)drawTriangle:(simd_float3)p0 p1:(simd_float3)p1 p2:(simd_float3)p2 color:(simd_float4)color
{
  planeLock_.lock();
  auto  vtx   = verticesPlane_[pageIndex_];
  auto *vtx3d = (VertexDataPrim3D *)vtx.contents + nbPlanes_;

  nbPlanes_ += 3;
  planeLock_.unlock();

  auto col16        = vcvt_f16_f32(color);
  vtx3d[0].position = p0;
  vtx3d[0].color    = col16;
  vtx3d[1].position = p1;
  vtx3d[1].color    = col16;
  vtx3d[2].position = p2;
  vtx3d[2].color    = col16;
}

//
- (void)drawPlane:(simd_float3)p0
               p1:(simd_float3)p1
               p2:(simd_float3)p2
               p3:(simd_float3)p3
            color:(simd_float4)color
{
  [self drawTriangle:p2 p1:p1 p2:p0 color:color];
  [self drawTriangle:p3 p1:p2 p2:p0 color:color];
}

//
- (void)render:(nullable id<MTLRenderCommandEncoder>)renderEncoder
        camera:(nonnull CameraData *)camera;
{
  [renderEncoder pushDebugGroup:@"Draw3D"];

  if (nbPrimitives_ > 0 || nbPlanes_ > 0)
  {
    auto uniformBuff = uniformBuffer_[pageIndex_];
    auto uniform     = (Uniforms *)uniformBuff.contents;

    auto mdlview                  = camera->getModelViewMatrix();
    uniform->perspectiveTransform = camera->getProjectionMatrix();
    uniform->worldTransform       = mdlview;
    uniform->worldNormalTransform =
        simd_matrix(mdlview.columns[0].xyz, mdlview.columns[1].xyz, mdlview.columns[2].xyz);
    [renderEncoder setRenderPipelineState:pipelineState_];

    // primitive draw
    if (nbPrimitives_ > 0)
    {
      auto vtx = vertices_[pageIndex_];
      [vtx didModifyRange:NSMakeRange(0, nbPrimitives_ * sizeof(VertexDataPrim3D))];
      [renderEncoder setVertexBuffer:vtx offset:0 atIndex:0];
      [renderEncoder setVertexBuffer:uniformBuff offset:0 atIndex:1];
      [renderEncoder setFragmentBuffer:uniformBuff offset:0 atIndex:1];
      [renderEncoder drawPrimitives:MTLPrimitiveTypeLine vertexStart:0 vertexCount:nbPrimitives_];
    }
    if (nbPlanes_ > 0)
    {
      auto vtx = verticesPlane_[pageIndex_];
      [vtx didModifyRange:NSMakeRange(0, nbPlanes_ * sizeof(VertexDataPrim3D))];
      [renderEncoder setVertexBuffer:vtx offset:0 atIndex:0];
      [renderEncoder setVertexBuffer:uniformBuff offset:0 atIndex:1];
      [renderEncoder setFragmentBuffer:uniformBuff offset:0 atIndex:1];
      [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:nbPlanes_];
    }

    nbPrimitives_ = 0;
    nbPlanes_     = 0;
  }

  [renderEncoder popDebugGroup];

  pageIndex_ = (pageIndex_ + 1) % 3;
}

@end
