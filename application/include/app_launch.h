//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#pragma once

#include <memory>
#include <simd/vector_types.h>

//
class ApplicationContext
{

public:
  ApplicationContext()          = default;
  virtual ~ApplicationContext() = default;

  virtual void Print(const char *msg, float x, float y)                      = 0;
  virtual void SetTextColor(float red, float green, float blue, float alpha) = 0;

  virtual void DrawLine(simd_float2 from, simd_float2 to, simd_float4 color) = 0;
  virtual void DrawRect(simd_float2 from, simd_float2 to, simd_float4 color) = 0;
  virtual void FillRect(simd_float2 from, simd_float2 to, simd_float4 color) = 0;
};

//
class ApplicationLoop
{
public:
  ApplicationLoop()          = default;
  virtual ~ApplicationLoop() = default;

  // start window size
  virtual void InitialWindowSize(double &width, double &height) {}
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
