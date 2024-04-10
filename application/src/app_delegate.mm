//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#import "app_delegate.h"
#import "renderer.h"
#import <AppKit/AppKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <MetalKit/MetalKit.h>
#include <simd/vector_types.h>

// c++ interface
#include "app_launch.h"

//
// InputView
//
@interface MyInputView : NSView
@end

@implementation MyInputView

- (BOOL)acceptsFirstResponder
{
  return YES;
}
- (void)keyDown:(NSEvent *)event
{
  // NSLog(@"keyDown");
}

- (void)keyUp:(NSEvent *)event
{
  // NSLog(@"keyDown");
}

- (void)mouseDown:(NSEvent *)event
{
  // NSLog@"mouseDown");
}

@end

//
// WindowDelegate
//
@interface WindowDelegate : NSObject <NSWindowDelegate>
@end

@implementation WindowDelegate
- (void)windowDidMove:(NSNotification *)notification
{
  // NSLog(@"DidMove");
}
- (void)windowDidBecomeKey:(NSNotification *)notification
{
  // NSLog(@"DidKey");
}
- (void)windowDidBecomeMain:(NSNotification *)notification
{
  // NSLog(@"DidMain");
}
@end

//
// 枠の無いウィンドウでもキー入力を受け付けるようにする
// https://stackoverflow.com/a/11638926
//
@interface BorderlessWindow : NSWindow
@end

@implementation BorderlessWindow

- (BOOL)canBecomeKeyWindow
{
  return YES;
}

- (BOOL)canBecomeMainWindow
{
  return YES;
}

@end

//
// AppDelegate
//
@interface AppDelegate ()
{
  NSWindow       *window_;
  MTKView        *view_;
  id<MTLDevice>   device_;
  MyInputView    *inputView_;
  Renderer       *renderer_;
  WindowDelegate *windowDelegate_;

  ApplicationLoop *appLoop_;
}

NSMenu *createMenu();

@end

@implementation AppDelegate

- (instancetype)initWithAppLoop:(nonnull ApplicationLoop *)appLoop
{
  self     = [super init];
  appLoop_ = appLoop;
  return self;
}

- (void)quitCallback:(NSObject *)sender
{
  //   NSLog(@"Quit Push");
  auto app = [NSApplication sharedApplication];
  [app terminate:sender];
}

- (NSMenu *)createMenu
{
  auto menu    = [[[NSMenu alloc] init] autorelease];
  auto appMenu = [[[NSMenu alloc] initWithTitle:@"Appname"] autorelease];
  @autoreleasepool
  {
    auto appMenuItem = [[[NSMenuItem alloc] init] autorelease];
    auto appName     = [NSRunningApplication.currentApplication localizedName];

    [appMenu addItemWithTitle:@"Quit" action:@selector(quitCallback:) keyEquivalent:@"q"];

    [appMenuItem setSubmenu:appMenu];

    [menu addItem:appMenuItem];
  }
  return menu;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
  auto           menu = [self createMenu];
  NSApplication *app  = notification.object;
  [app setMainMenu:menu];
  [app setActivationPolicy:NSApplicationActivationPolicy::NSApplicationActivationPolicyRegular];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  CGRect frame = {0.0, 0.0, 1600.0, 960.0};

  appLoop_->InitialWindowSize(frame.size.width, frame.size.height);
  double clearRed   = 0.0;
  double clearGreen = 0.0;
  double clearBlue  = 0.0;
  double clearAlpha = 1.0;
  appLoop_->WindowClearColor(clearRed, clearGreen, clearBlue, clearAlpha);

  window_                       = [[BorderlessWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:false];
  device_                       = MTLCreateSystemDefaultDevice();
  view_                         = [[MTKView alloc] initWithFrame:frame device:device_];
  view_.colorPixelFormat        = MTLPixelFormatRGBA8Unorm_sRGB;
  view_.clearColor              = MTLClearColorMake(clearRed, clearGreen, clearBlue, clearAlpha);
  view_.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
  view_.clearDepth              = 1.0f;
  view_.sampleCount             = 1;

  renderer_      = [[Renderer alloc] initWithMetalKitView:view_];
  view_.delegate = renderer_;
  [renderer_ setApplicationLoop:appLoop_];
  [renderer_ mtkView:view_ drawableSizeWillChange:view_.drawableSize];

  windowDelegate_     = [[WindowDelegate alloc] init];
  window_.delegate    = windowDelegate_;
  window_.contentView = view_;
  [window_ center];

  inputView_ = [[MyInputView alloc] initWithFrame:view_.frame];
  [view_ addSubview:inputView_];
  [window_ makeFirstResponder:view_];

  window_.title = @"Test";
  [window_ makeKeyAndOrderFront:nil];

  NSApplication *app = notification.object;
  [app activateIgnoringOtherApps:true];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
  NSLog(@"terminate APP");
  [renderer_ release];
  [windowDelegate_ release];
  [device_ release];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
  return YES;
}

@end

//
void LaunchApplication(std::shared_ptr<ApplicationLoop> apploop)
{
  AppDelegate *del  = [[AppDelegate alloc] initWithAppLoop:apploop.get()];
  auto         sapp = [NSApplication sharedApplication];
  [sapp setDelegate:del];
  [sapp run];
}

//
