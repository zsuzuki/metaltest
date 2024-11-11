//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#pragma once

#include "sprite4cpp.h"
#include <memory>
#include <simd/vector_types.h>

class CameraData;

//
class ApplicationContext
{

public:
  ApplicationContext()          = default;
  virtual ~ApplicationContext() = default;

  // text
  virtual void Print(const char *msg, float x, float y)                      = 0;
  virtual void SetTextColor(float red, float green, float blue, float alpha) = 0;

  // 2D
  virtual void DrawLine(simd_float2 from, simd_float2 to, simd_float4 color)                    = 0;
  virtual void DrawRect(simd_float2 from, simd_float2 to, simd_float4 color)                    = 0;
  virtual void FillRect(simd_float2 from, simd_float2 to, simd_float4 color)                    = 0;
  virtual void DrawPolygon(simd_float2 pos, float rad, float rot, int sides, simd_float4 color) = 0;
  virtual void FillPolygon(simd_float2 pos, float rad, float rot, int sides, simd_float4 color) = 0;

  using SpritePtr                                   = std::shared_ptr<SpriteCpp>;
  virtual SpritePtr CreateSprite(std::string fname) = 0;
  virtual void      DrawSprite(SpritePtr spr)       = 0;

  // 3D
  virtual CameraData &GetCamera() = 0;

  virtual void DrawLine3D(simd_float3 from, simd_float3 to, simd_float4 color) = 0;
  virtual void DrawTriangle3D(simd_float3 p0, simd_float3 p1, simd_float3 p2,
                              simd_float4 color)                               = 0;
  virtual void DrawPlane3D(simd_float3 p0, simd_float3 p1, simd_float3 p2, simd_float3 p3,
                           simd_float4 color)                                  = 0;
};

//
class ApplicationLoop
{
public:
  ApplicationLoop()          = default;
  virtual ~ApplicationLoop() = default;

  // start window size
  virtual void InitialWindowSize(double &width, double &height) {}
  // to close window
  virtual void WillCloseWindow() {}
  // window clear color
  virtual void WindowClearColor(double &red, double &green, double &blue, double &alpha) {}
  // resize window
  virtual void ResizeWindow(double width, double height) {}

  // main update loop
  virtual void Update(ApplicationContext &ctx) = 0;
};

//
void LaunchApplication(std::shared_ptr<ApplicationLoop> apploop);

//
