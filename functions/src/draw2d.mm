//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#import "draw2d.h"
#import "font_render.h"
#include "shader_def.h"
#import "sprite.h"
#import "texture.h"
#import <Metal/Metal.h>
#include <arm_neon.h>
#include <list>
#include <memory>
#include <simd/simd.h>

namespace
{
// 文字列管理
struct DrawString
{
  Texture    *stringTex_;
  simd_float2 pos_[4];
  simd_float4 color_;
  BOOL        keep_;

  ~DrawString() { [stringTex_ release]; }
};
using DrawStringPtr = std::shared_ptr<DrawString>;

} // namespace

//
//
//
@interface Draw2D ()
{
}
@end

@implementation Draw2D
{
  id<MTLDevice>  device_;
  id<MTLBuffer>  uniformBuffer_;
  MTLPixelFormat colorFormat_;
  MTLPixelFormat depthFormat_;
  NSUInteger     sampleCount_;
  CGFloat        contentScale_;
  NSUInteger     pageIndex_;

  // text draw
  id<MTLDepthStencilState>   depthState_;
  id<MTLRenderPipelineState> pipelineStateText_;
  FontRender                *fontRender_;
  id<MTLBuffer>              textVtx_[3];
  simd_float4                textColor_;
  BOOL                       requestClearText_;
  std::list<DrawStringPtr>   drawStringList;
  std::list<DrawStringPtr>   drawStringListBack;

  // primitive
  id<MTLRenderPipelineState> pipelineStatePrim_;
  id<MTLBuffer>              vertices_[3];
  NSUInteger                 nbPrimitives_;

  // sprite
  NSMutableArray<Sprite *> *spriteList;
}

@synthesize screenSize;

- (CGFloat)P:(CGFloat)num
{
  return num * contentScale_;
}

- (void)drawLine:(simd_float2)from to:(simd_float2)to color:(simd_float4)color
{
  auto  vtx   = vertices_[pageIndex_];
  auto *vtx2d = (VertexDataPrim2D *)vtx.contents + nbPrimitives_;

  auto col16        = vcvt_f16_f32(color);
  vtx2d[0].position = from * contentScale_;
  vtx2d[0].color    = col16;
  vtx2d[1].position = to * contentScale_;
  vtx2d[1].color    = col16;

  nbPrimitives_ += 2;
}

- (void)drawRect:(simd_float2)from to:(simd_float2)to color:(simd_float4)color
{
  auto  vtx   = vertices_[pageIndex_];
  auto *vtx2d = (VertexDataPrim2D *)vtx.contents + nbPrimitives_;

  from *= contentScale_;
  to *= contentScale_;

  auto col16        = vcvt_f16_f32(color);
  vtx2d[0].position = from;
  vtx2d[0].color    = col16;
  vtx2d[1].position = simd_make_float2(to.x, from.y);
  vtx2d[1].color    = col16;
  vtx2d[2].position = from;
  vtx2d[2].color    = col16;
  vtx2d[3].position = simd_make_float2(from.x, to.y);
  vtx2d[3].color    = col16;
  vtx2d[4].position = simd_make_float2(to.x, from.y);
  vtx2d[4].color    = col16;
  vtx2d[5].position = to;
  vtx2d[5].color    = col16;
  vtx2d[6].position = simd_make_float2(from.x, to.y);
  vtx2d[6].color    = col16;
  vtx2d[7].position = to;
  vtx2d[7].color    = col16;

  nbPrimitives_ += 8;
}

// テキスト描画カラー
- (void)setTextColorRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
  textColor_ = simd_make_float4(red, green, blue, alpha);
}

// テキスト描画
- (void)print:(nonnull NSString *)message x:(CGFloat)x y:(CGFloat)y keep:(BOOL)keep
{
  [fontRender_ Render:message
             callback:^(CGContextRef ctx, CGRect rect) {
               auto dstr        = std::make_shared<DrawString>();
               dstr->stringTex_ = [[Texture alloc] initWithMemory:ctx device:device_];
               dstr->color_     = textColor_;
               dstr->keep_      = keep;
               const CGFloat x1 = [self P:x + rect.origin.x];
               const CGFloat y1 = [self P:y + rect.origin.y];
               const CGFloat x2 = x1 + [self P:rect.size.width];
               const CGFloat y2 = y1 + [self P:rect.size.height];
               dstr->pos_[0]    = simd_make_float2(x2, y1);
               dstr->pos_[1]    = simd_make_float2(x1, y1);
               dstr->pos_[2]    = simd_make_float2(x2, y2);
               dstr->pos_[3]    = simd_make_float2(x1, y2);
               drawStringList.push_back(dstr);
             }];
}

- (void)print:(nonnull NSString *)message x:(CGFloat)x y:(CGFloat)y
{
  [self print:message x:x y:y keep:NO];
}

// テキストクリア
- (void)clearText
{
  requestClearText_ = YES;
}

//
- (BOOL)initializePipeline:(id<MTLLibrary>)library
{
  NSError *error        = nil;
  auto     pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];

  auto vertexFunction   = [library newFunctionWithName:@"vert2d"];
  auto fragmentFunction = [library newFunctionWithName:@"frag2d"];

  // text
  pipelineDesc.label                        = @"PipelineText";
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

  pipelineStateText_ = [device_ newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];

  // primitive
  auto vertexPrimFunction   = [library newFunctionWithName:@"primVert2d"];
  auto fragmentPrimFunction = [library newFunctionWithName:@"primFrag2d"];

  pipelineDesc.label             = @"Pipeline2D";
  pipelineDesc.rasterSampleCount = sampleCount_;
  pipelineDesc.vertexFunction    = vertexPrimFunction;
  pipelineDesc.fragmentFunction  = fragmentPrimFunction;

  pipelineStatePrim_ = [device_ newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];

  [pipelineDesc release];
  return YES;
}

//
- (void)initializeDepthState
{
  auto depthStateDesc                 = [[MTLDepthStencilDescriptor alloc] init];
  depthStateDesc.depthCompareFunction = MTLCompareFunctionAlways;
  depthStateDesc.depthWriteEnabled    = NO;
  depthState_                         = [device_ newDepthStencilStateWithDescriptor:depthStateDesc];
}

// 初期化
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view
                                   shaderlib:(nonnull id<MTLLibrary>)library
{
  self = [super init];
  if (self != nil)
  {
    device_        = view.device;
    colorFormat_   = view.colorPixelFormat;
    depthFormat_   = view.depthStencilPixelFormat;
    sampleCount_   = view.sampleCount;
    uniformBuffer_ = [device_ newBufferWithLength:sizeof(Uniforms2D)
                                          options:MTLResourceStorageModeShared];
    contentScale_  = [[NSScreen mainScreen] backingScaleFactor];
    pageIndex_     = 0;
    nbPrimitives_  = 0;
    spriteList     = [[NSMutableArray alloc] init];

    uniformBuffer_.label = @"UniformBuffer2D";

    if ([self initializePipeline:library] == NO)
    {
      NSLog(@"init failed pipeline");
    }
    [self initializeDepthState];

    for (int i = 0; i < 3; i++)
    {
      textVtx_[i]  = [device_ newBufferWithLength:sizeof(VertexDataPrim2D) * 4 * 500
                                         options:MTLResourceStorageModeShared];
      vertices_[i] = [device_ newBufferWithLength:sizeof(VertexDataPrim2D) * 4 * 500
                                          options:MTLResourceStorageModeShared];
    }
    requestClearText_ = NO;
    fontRender_       = [[FontRender alloc] init];
    [fontRender_ SetSize:24.0f];
    [self setTextColorRed:1.0f green:1.0f blue:1.0f alpha:1.0f];
  }

  return self;
}

//
- (void)dealloc
{
  [spriteList release];
  for (int i = 0; i < 3; i++)
  {
    [textVtx_[i] release];
    [vertices_[i] release];
  }
  [fontRender_ release];
  [uniformBuffer_ release];
  [depthState_ release];
  [pipelineStateText_ release];
  [pipelineStatePrim_ release];
  [super dealloc];
}

//
- (void)setupDrawText
{
  auto               textVtx  = textVtx_[pageIndex_];
  __block NSUInteger vtxCount = 0;
  [spriteList
      enumerateObjectsUsingBlock:^(Sprite *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        auto  poslist = [obj update];
        auto *sprvtx  = (VertexDataPrim2D *)textVtx.contents + vtxCount;
        for (int i = 0; i < 4; i++)
        {
          sprvtx[i].position = poslist[i];
          sprvtx[i].color    = vcvt_f16_f32(obj.color);
        }
        vtxCount += 4;
      }];
  for (auto dstr : drawStringList)
  {
    auto *vtx2d = (VertexDataPrim2D *)textVtx.contents + vtxCount;
    for (int i = 0; i < 4; i++)
    {
      vtx2d[i].position = dstr->pos_[i];
      vtx2d[i].color    = vcvt_f16_f32(dstr->color_);
    }
    vtxCount += 4;
  }
  [textVtx didModifyRange:NSMakeRange(0, vtxCount * sizeof(VertexDataPrim2D))];
}

//
- (void)drawText:(id<MTLRenderCommandEncoder>)renderEncoder
{
  __block NSUInteger vtxCount = 0;
  [spriteList
      enumerateObjectsUsingBlock:^(Sprite *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        [renderEncoder setFragmentTexture:obj.texObj atIndex:TextureIndexColor];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                          vertexStart:vtxCount
                          vertexCount:4];
        vtxCount += 4;
      }];
  for (auto dstr : drawStringList)
  {
    [renderEncoder setFragmentTexture:dstr->stringTex_.object atIndex:TextureIndexColor];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:vtxCount vertexCount:4];
    vtxCount += 4;
  }
  drawStringList.swap(drawStringListBack);
  drawStringList.clear();
}

// 描画
- (void)render:(nullable id<MTLRenderCommandEncoder>)renderEncoder
{
  [renderEncoder pushDebugGroup:@"Draw2D"];

  auto *uniform2d    = (Uniforms2D *)uniformBuffer_.contents;
  uniform2d->size[0] = screenSize.width;
  uniform2d->size[1] = screenSize.height;

  if (nbPrimitives_ > 0)
  {
    // primitive draw
    auto vtx = vertices_[pageIndex_];
    [vtx didModifyRange:NSMakeRange(0, nbPrimitives_ * sizeof(VertexDataPrim2D))];
    [renderEncoder setRenderPipelineState:pipelineStatePrim_];

    [renderEncoder setVertexBuffer:uniformBuffer_ offset:0 atIndex:1];
    [renderEncoder setFragmentBuffer:uniformBuffer_ offset:0 atIndex:1];
    [renderEncoder setVertexBuffer:vtx offset:0 atIndex:0];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeLine vertexStart:0 vertexCount:nbPrimitives_];
    nbPrimitives_ = 0;
  }

  // text draw
  [renderEncoder setRenderPipelineState:pipelineStateText_];
  [renderEncoder setDepthStencilState:depthState_];

  [renderEncoder setVertexBuffer:uniformBuffer_ offset:0 atIndex:1];
  [renderEncoder setFragmentBuffer:uniformBuffer_ offset:0 atIndex:1];

  [self setupDrawText];
  [renderEncoder setVertexBuffer:textVtx_[pageIndex_] offset:0 atIndex:0];
  [self drawText:renderEncoder];

  [renderEncoder popDebugGroup];

  [spriteList removeAllObjects];
  pageIndex_ = (pageIndex_ + 1) % 3;
}

//
- (nonnull NSArray<Sprite *> *)createSprites:(nonnull NSArray<NSString *> *)fileList
{
  auto texloader = [[MTKTextureLoader alloc] initWithDevice:device_];

  NSMutableArray<NSURL *> *urlList = [[NSMutableArray alloc] init];
  [fileList
      enumerateObjectsUsingBlock:^(NSString *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        NSURL *fURL = [[NSBundle mainBundle] URLForResource:obj withExtension:nil];
        [urlList addObject:fURL];
      }];

  NSMutableArray<Sprite *> *sprList = [[NSMutableArray alloc] init];
  [texloader newTexturesWithContentsOfURLs:urlList
                                   options:nil
                         completionHandler:^(NSArray<id<MTLTexture>> *_Nonnull textures,
                                             NSError *_Nullable error) {
                           [textures enumerateObjectsUsingBlock:^(id<MTLTexture> _Nonnull obj,
                                                                  NSUInteger idx,
                                                                  BOOL *_Nonnull stop) {
                             auto spr = [[Sprite alloc] initWithTexture:obj];
                             [sprList addObject:spr];
                           }];
                         }];
  [urlList release];
  return sprList;
}

//
- (nonnull NSArray<Sprite *> *)createSpritesByImage:(NSArray<NSString *> *)fileList
{
  NSMutableArray<Sprite *> *sprList = [[NSMutableArray alloc] init];
  [fileList
      enumerateObjectsUsingBlock:^(NSString *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        NSURL *fURL         = [[NSBundle mainBundle] URLForResource:obj withExtension:nil];
        auto   img          = [[CIImage alloc] initWithContentsOfURL:fURL];
        auto   texdesc      = [[MTLTextureDescriptor alloc] init];
        texdesc.width       = img.extent.size.width;
        texdesc.height      = img.extent.size.height;
        texdesc.pixelFormat = colorFormat_;
        texdesc.textureType = MTLTextureType2D;
        texdesc.storageMode = MTLStorageModeManaged;
        texdesc.usage       = MTLResourceUsageRead | MTLResourceUsageWrite;
        auto tex            = [device_ newTextureWithDescriptor:texdesc];
        auto spr            = [[Sprite alloc] initWithImage:img texture:tex];
        [sprList addObject:spr];
        [spr release];
        [texdesc release];
      }];
  return sprList;
}

//
- (void)drawSprite:(Sprite *)sprite
{
  [spriteList addObject:sprite];
}

@end
