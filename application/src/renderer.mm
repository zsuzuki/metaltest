//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#import "renderer.h"
#include "app_launch.h"
#import "camera.h"
#import "draw2d.h"
#import "draw3d.h"
#import "sprite.h"
#include <Metal/Metal.h>
#include <memory>
#import <simd/simd.h>

static const NSUInteger MaxBuffersInFlight = 3;

class AppCtx : public ApplicationContext
{
public:
  Draw2D *draw2d_;

  AppCtx()           = default;
  ~AppCtx() override = default;

  void Print(const char *msg, float x, float y) override
  {
    [draw2d_ print:[NSString stringWithUTF8String:msg] x:x y:y];
  }
  void SetTextColor(float red, float green, float blue, float alpha) override
  {
    [draw2d_ setTextColorRed:red green:green blue:blue alpha:alpha];
  }

  void DrawLine(simd_float2 from, simd_float2 to, simd_float4 color) override
  {
    [draw2d_ drawLine:from to:to color:color];
  }
  void DrawRect(simd_float2 from, simd_float2 to, simd_float4 color) override
  {
    [draw2d_ drawRect:from to:to color:color];
  }
  void FillRect(simd_float2 from, simd_float2 to, simd_float4 color) override
  {
    [draw2d_ fillRect:from to:to color:color];
  }
};

@implementation Renderer
{
  dispatch_semaphore_t     renderSemaphore_;
  uint8_t                  uniformBufferIndex_;
  id<MTLDevice>            device_;
  id<MTLCommandQueue>      commandQueue_;
  id<MTLLibrary>           shaderLibrary_;
  id<MTLDepthStencilState> depthState_;

  ApplicationLoop *appLoop_;

  CameraData camera_;
  Draw2D    *draw2d_;
  Draw3D    *draw3d_;
}

+ (id<MTLLibrary>)createShaderLibrary:(id<MTLDevice>)device fromName:(NSString *)libraryName
{
  NSURL *libraryURL = [[NSBundle mainBundle] URLForResource:libraryName withExtension:@"metallib"];
  if (libraryURL == nil)
  {
    NSLog(@"Couldn't find library file: %@", libraryName);
    return nil;
  }

  NSError       *libraryError = nil;
  id<MTLLibrary> library      = [device newLibraryWithURL:libraryURL error:&libraryError];
  if (library == nil)
  {
    NSLog(@"Couldn't create library: %@", libraryName);
    return nil;
  }

  return library;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
{
  self = [super init];
  if (self != nil)
  {
    device_          = view.device;
    renderSemaphore_ = dispatch_semaphore_create(MaxBuffersInFlight);
    commandQueue_    = [device_ newCommandQueue];

    // initialize
    shaderLibrary_ = [Renderer createShaderLibrary:device_ fromName:@"shaders/shaders"];
    draw2d_        = [[Draw2D alloc] initWithMetalKitView:view shaderlib:shaderLibrary_];
    draw3d_        = [[Draw3D alloc] initWithMetalKitView:view shaderlib:shaderLibrary_];

    //

    auto depthStateDesc                 = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled    = YES;
    depthState_ = [device_ newDepthStencilStateWithDescriptor:depthStateDesc];
  }

  return self;
}

- (void)dealloc
{
  [depthState_ release];
  [draw2d_ release];
  [draw3d_ release];
  [super dealloc];
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
  dispatch_semaphore_wait(renderSemaphore_, DISPATCH_TIME_FOREVER);

  uniformBufferIndex_ = (uniformBufferIndex_ + 1) % MaxBuffersInFlight;

  id<MTLCommandBuffer> commandBuffer = [commandQueue_ commandBuffer];
  commandBuffer.label                = @"MyCommand";

  __block dispatch_semaphore_t block_sema = renderSemaphore_;
  [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
    dispatch_semaphore_signal(block_sema);
  }];

  AppCtx appctx;
  appctx.draw2d_ = draw2d_;
  appLoop_->Update(appctx);

  // render
  auto renderPassDescriptor = view.currentRenderPassDescriptor;

  if (renderPassDescriptor != nil)
  {
    auto renderEncoder  = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    renderEncoder.label = @"MyRenderEncoder";

    [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
    [renderEncoder setCullMode:MTLCullModeBack];
    [renderEncoder setDepthStencilState:depthState_];

    // 3D Graphics
    [draw3d_ render:renderEncoder camera:&camera_];

    // 2D Graphics
    [renderEncoder setCullMode:MTLCullModeNone];
    [draw2d_ render:renderEncoder];

    // Game Render End

    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
  }

  [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
  float aspect       = size.width / (float)size.height;
  draw2d_.screenSize = size;
  camera_.buildPerspective(45.0f, aspect, 0.1f, 1000.0f);
  appLoop_->ResizeWindow(size.width, size.height);
}

- (void)setApplicationLoop:(nonnull ApplicationLoop *)appLoop
{
  appLoop_ = appLoop;
}

@end
