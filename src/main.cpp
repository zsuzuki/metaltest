//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#include <app_launch.h>
#include <array>
#include <camera.h>
#include <cmath>
#include <format>
#include <game_pad.h>
#include <iostream>
#include <memory>
#include <simd/vector_make.h>

namespace
{
//
constexpr double WindowWidth  = 1600.0;
constexpr double WindowHeight = 800.0;
} // namespace

//
//
//
class MainLoop : public ApplicationLoop
{

  GamePad::PadState padState_;

public:
  MainLoop()           = default;
  ~MainLoop() override = default;

  void InitialWindowSize(double &width, double &height) override
  {
    std::cout << std::format("Default window size: {} x {}\n", width, height);
    width  = WindowWidth;
    height = WindowHeight;
  }

  void WillCloseWindow() override { std::cout << std::format("To Close Window\n"); }

  void WindowClearColor(double &red, double &green, double &blue, double &alpha) override
  {
    std::cout << std::format("Default clear color: R={} G={} B={} A={}\n", red, green, blue, alpha);
    blue = 0.05;
  }

  void ResizeWindow(double width, double height) override
  {
    // std::cout << std::format("Resize window: width={}, height={}", width, height) << std::endl;
  }

  void Update(ApplicationContext &ctx) override
  {
    static int cnt   = 0;
    auto       hello = std::format("こんにちは: {}", cnt);
    ctx.Print(hello.c_str(), 200, 200);
    ctx.DrawRect({190, 190}, {600, 230}, {0, 1, 0, 1});

    auto  base = simd_make_float2(300.0f, 400.0f);
    float deg  = ((cnt % 360) / 360.0f) * M_PI * 2.0f;
    auto  tgt  = simd_make_float2(std::sinf(deg), std::cosf(deg));
    tgt        = base + tgt * 100.0f;

    ctx.DrawLine(base, tgt, {1, 1, 1, 1});

    {
      // test 3D
      static auto look   = simd_make_float3(0.0f, 0.0f, 0.0f);
      simd_float3 eye    = simd_make_float3(10.0f, 7.0f, 10.0f);
      simd_float3 up     = simd_make_float3(0.0f, 1.0f, 0.0f);
      auto       &camera = ctx.GetCamera();
      camera.buildModelView(eye, look, up);

      auto p0 = simd_make_float3(5.0f, 0.0f, 5.0f);
      auto p1 = simd_make_float3(-5.0f, 0.0f, 5.0f);
      auto p2 = simd_make_float3(-5.0f, 0.0f, -5.0f);
      auto p3 = simd_make_float3(5.0f, 0.0f, -5.0f);
      ctx.DrawLine3D(p0, p1, {1, 1, 1, 1});
      ctx.DrawLine3D(p1, p2, {1, 1, 1, 1});
      ctx.DrawLine3D(p2, p3, {1, 1, 1, 1});
      ctx.DrawLine3D(p3, p0, {1, 1, 1, 1});
      ctx.DrawPlane3D(p0, p1, p2, p3, {0.1, 0.1, 0.5, 1});
      float deg2 = (((cnt + 120) % 360) / 360.0f) * M_PI * 2.0f;
      float deg3 = (((cnt + 240) % 360) / 360.0f) * M_PI * 2.0f;
      auto  tp0  = simd_make_float3(std::sinf(deg), 1.0f, std::cosf(deg));
      auto  tp1  = simd_make_float3(std::sinf(deg2), 1.0f, std::cosf(deg2));
      auto  tp2  = simd_make_float3(std::sinf(deg3), 1.0f, std::cosf(deg3));
      ctx.DrawTriangle3D(tp0, tp1, tp2, {1, 0, 0, 1});
    }

    GamePad::GetPadState(0, padState_);
    if (padState_.enabled_)
    {
      std::array<bool, 4> btn{};
      btn[0]      = padState_.buttonA.Pressed();
      btn[1]      = padState_.buttonB.Pressed();
      btn[2]      = padState_.buttonC.Pressed();
      btn[3]      = padState_.buttonD.Pressed();
      auto  color = simd_make_float4(0, 1, 0, 1);
      float y     = 100;
      for (int i = 0; i < btn.size(); i++)
      {
        auto p1 = simd_make_float2(900, y + i * 60);
        auto p2 = simd_make_float2(950, y + 50 + i * 60);
        ctx.DrawRect(p1, p2, {1, 1, 1, 1});
        if (btn[i])
        {
          ctx.FillRect(p1, p2, color);
        }
      }
    }
    cnt++;
  }
};

//
//
//
int main(int argc, char **argv)
{
  auto mainloop = std::make_shared<MainLoop>();
  LaunchApplication(mainloop);

  return 0;
}

//
