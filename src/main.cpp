//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#include <app_launch.h>
#include <array>
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
    std::cout << std::format("Default window size: {} x {}", width, height) << std::endl;
    width  = WindowWidth;
    height = WindowHeight;
  }

  void WindowClearColor(double &red, double &green, double &blue, double &alpha) override
  {
    std::cout << std::format("Default clear color: R={} G={} B={} A={}", red, green, blue, alpha)
              << std::endl;
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
    cnt++;

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
