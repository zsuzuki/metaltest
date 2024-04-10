//
// Copyright 2023 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#import "font_render.h"
#import <AppKit/AppKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreText/CTLine.h>
#include <Foundation/Foundation.h>
#import <string>

//
//
//
@interface FontRender ()
{
  NSString     *fontName_;
  NSFont       *font_;
  NSDictionary *attributes_;
  NSColor      *color_;
  CGFloat       size_;
}
@end

//
//
//
@implementation FontRender

- (id)init
{
  self = [super init];
  if (self != nil)
  {
    size_     = 20.0f;
    fontName_ = @"ヒラギノ角ゴシック";
    // fontName_ = @"IBM Plex Sans JP";
    // fontName_ = @"ＤＦＰ角POPW5";
    // fontName_ = @"ＤＦＰ細丸ゴシック体";
    [self makeFont];
    [self SetColor:1.0f green:1.0f blue:1.0f];
  }
  return self;
}

- (void)dealloc
{
  [self ClearFont];
  [super dealloc];
}

- (void)ClearFont
{
  [self clearAttribute];
  [color_ release];
  font_  = nil;
  color_ = nil;
}

// internal function
- (void)clearAttribute
{
  attributes_ = nil;
}

- (void)makeFont
{
  font_ = [[NSFont fontWithName:fontName_ size:size_] retain];
  [self clearAttribute];
}

//
//
//
- (void)SetFont:(const char *)fontName
{
  fontName_ = [NSString stringWithUTF8String:fontName];
  [self makeFont];
}
- (void)SetSize:(float)fontSize
{
  size_ = fontSize;
  [self makeFont];
}
- (void)SetColor:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
{
  [self SetColor:red green:green blue:blue alpha:1.0f];
}
- (void)SetColor:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
  color_ = [NSColor colorWithRed:red green:green blue:blue alpha:alpha];
  [self clearAttribute];
}

//
//
//
- (void)Render:(NSString *)message callback:(RenderCallback)callback
{
  // フォント情報がなければ精製
  if (attributes_ == nil)
  {
    auto attrib = @{
      NSFontAttributeName : font_,
      NSForegroundColorAttributeName : color_,
    };
    attributes_ = [attrib retain];
  }

  // セットアップ
  CGFloat ascent, descent;
  auto    attrStr    = [[NSAttributedString alloc] initWithString:message attributes:attributes_];
  auto    colorSpace = [[NSColorSpace deviceRGBColorSpace] CGColorSpace];
  auto    line       = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attrStr);
  auto    rect       = CTLineGetImageBounds(line, nullptr);
  auto    baseWidth  = std::ceil(CTLineGetTypographicBounds(line, &ascent, &descent, nullptr));
  auto    baseHeight = std::ceil(rect.size.height + descent);
  auto    textWidth  = std::ceil(baseWidth);
  auto    textHeight = std::ceil(baseHeight);
  auto    originX    = rect.origin.x;
  auto    originY    = -rect.origin.y;

  // レンダリング
  auto ctx = CGBitmapContextCreate(
      nullptr, textWidth, textHeight, 8, 4 * textWidth, colorSpace, kCGImageAlphaPremultipliedLast);
  auto offsetY = descent + originY;
  CGContextSetTextPosition(ctx, 0, offsetY);
  CTLineDraw(line, ctx);
  CGFloat width  = CGBitmapContextGetWidth(ctx);
  CGFloat height = CGBitmapContextGetHeight(ctx);

  auto bbox = CGRectMake(originX, originY, width, height);
  callback(ctx, bbox);

  [attrStr release];
  CFRelease(colorSpace);
  CFRelease(line);
  CFRelease(ctx);
}

@end
