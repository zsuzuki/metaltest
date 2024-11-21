//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#include <app_launch.h>
#include <arm_neon.h>
#include <array>
#include <camera.h>
#include <cmath>
#include <format>
#include <game_pad.h>
#include <iostream>
#include <keyboard.h>
#include <memory>
#include <simd/quaternion.h>
#include <simd/vector_make.h>
#include <sprite4cpp.h>

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

  GamePad::PadState padState_{};
  bool              onKeyW_ = false;
  bool              onKeyA_ = false;
  bool              onKeyS_ = false;
  bool              onKeyD_ = false;

  std::shared_ptr<SpriteCpp> sprite_;

public:
  MainLoop()           = default;
  ~MainLoop() override = default;

  void InitialWindowSize(double &width, double &height) override
  {
    std::cout << std::format("Default window size: {} x {}\n", width, height);
    width  = WindowWidth;
    height = WindowHeight;
  }

  void WillCloseWindow() override
  {
    if (sprite_)
    {
      sprite_.reset();
    }
    std::cout << std::format("To Close Window\n");
  }

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
    Keyboard::Fetch(
        [&](Keyboard::KeyCode code, bool press)
        {
          switch (code)
          {
          case Keyboard::KeyCode::W:
            onKeyW_ = press;
            break;
          case Keyboard::KeyCode::A:
            onKeyA_ = press;
            break;
          case Keyboard::KeyCode::S:
            onKeyS_ = press;
            break;
          case Keyboard::KeyCode::D:
            onKeyD_ = press;
            break;
          default:
            std::cout << "Key Event: " << (int)code << ", " << (press ? "On" : "Off") << "\n";
            break;
          }
        });

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
    padState_.buttonUp.overridePress(onKeyW_);
    padState_.buttonLeft.overridePress(onKeyA_);
    padState_.buttonDown.overridePress(onKeyS_);
    padState_.buttonRight.overridePress(onKeyD_);
    if (padState_.enabled_)
    {
      static simd_float3 tpos = simd_make_float3(0.0f, 2.0f, 0.0f);
      static float       rotY = 0.0f;
      rotY += (padState_.triggerL - padState_.triggerR) * 0.1f;
      auto rotQ = simd_quaternion(rotY, simd_make_float3(0.0f, 1.0f, 0.0f));
      tpos += simd_act(rotQ, simd_make_float3(-padState_.leftX, 0.0f, padState_.leftY)) * 0.05f;
      auto npos = vmaxq_f32(float32x4_t{tpos.x, tpos.y, tpos.z, 0.0f}, vdupq_n_f32(-8.0f));
      npos      = vminq_f32(npos, vdupq_n_f32(8.0f));
      tpos      = simd_make_float3(npos[0], npos[1], npos[2]);

      auto tp0 = simd_act(rotQ, simd_make_float3(0.0f, 0.0f, 1.0f)) + tpos;
      auto tp1 = simd_act(rotQ, simd_make_float3(1.0f, 0.0f, 0.0f)) + tpos;
      auto tp2 = simd_act(rotQ, simd_make_float3(-1.0f, 0.0f, 0.0f)) + tpos;
      ctx.DrawTriangle3D(tp0, tp1, tp2, {1, 1, 0, 1});

      std::array<bool, 11> btn{};
      btn[0]      = padState_.buttonA.Pressed();
      btn[1]      = padState_.buttonB.Pressed();
      btn[2]      = padState_.buttonC.Pressed();
      btn[3]      = padState_.buttonD.Pressed();
      btn[4]      = padState_.shoulderL.Pressed();
      btn[5]      = padState_.shoulderR.Pressed();
      btn[6]      = padState_.thumbL.Pressed();
      btn[7]      = padState_.thumbR.Pressed();
      btn[8]      = padState_.buttonMenu.Pressed();
      btn[9]      = padState_.buttonOptions.Pressed();
      btn[10]     = padState_.buttonTouch.Pressed();
      auto  color = simd_make_float4(0, 1, 0, 1);
      float y     = 100;
      for (int i = 0; i < btn.size(); i++)
      {
        auto p1 = simd_make_float2(1200, y + i * 60);
        auto p2 = simd_make_float2(1250, y + 50 + i * 60);
        ctx.DrawRect(p1, p2, {1, 1, 1, 1});
        if (btn[i])
        {
          ctx.FillRect(p1, p2, color);
        }
      }

      // dpad
      auto drawdp = [&](bool val, float x, float y)
      {
        auto p1 = simd_make_float2(x - 20, y - 20);
        auto p2 = simd_make_float2(x + 20, y + 20);
        ctx.DrawRect(p1, p2, {1, 1, 1, 1});
        if (val)
        {
          p1 += 2;
          p2 -= 2;
          ctx.FillRect(p1, p2, color);
        }
      };
      drawdp(padState_.buttonLeft.Pressed(), 900, 500);
      drawdp(padState_.buttonRight.Pressed(), 1000, 500);
      drawdp(padState_.buttonUp.Pressed(), 950, 450);
      drawdp(padState_.buttonDown.Pressed(), 950, 550);

      // stick circle
      auto drawan = [&](float val, float y)
      {
        if (val != 0.0)
        {
          float lx = val < 0 ? val : 0.0;
          float rx = val > 0 ? val : 0.0;
          lx       = lx * 300.0 + 450.0;
          rx       = rx * 300.0 + 450.0;
          ctx.FillRect({lx, y}, {rx, y + 30}, {0.5, 1, 0.5, 1});
        }
      };
      drawan(padState_.triggerL, 650);
      drawan(padState_.triggerR, 700);

      auto anbase = simd_make_float2(300, 500);
      if (padState_.thumbL.Pressed())
      {
        ctx.FillPolygon(anbase, 80, 0, 20, {1.0f, 0.9f, 0.0f, 0.3f});
      }
      ctx.DrawPolygon(anbase, 100, 0, 20, {1, 1, 1, 1});
      auto an0pos = simd_make_float2(padState_.leftX, -padState_.leftY) * 100 + anbase;
      ctx.DrawLine(anbase, an0pos, {0, 1, 0, 1});

      anbase.x += 350;
      if (padState_.thumbR.Pressed())
      {
        ctx.FillPolygon(anbase, 80, 0, 20, {1.0f, 0.9f, 0.0f, 0.3f});
      }
      ctx.DrawPolygon(anbase, 100, 0, 20, {1, 0.5, 0.5, 1});
      auto an1pos = simd_make_float2(padState_.rightX, -padState_.rightY) * 100 + anbase;
      ctx.DrawLine(anbase, an1pos, {0, 1, 0, 1});

      // motion
      auto center = simd_make_float3(0.0f, 5.0f, 0.0f);
      auto xaxs   = simd_make_float3(2.0f, 0.0f, 0.0f);
      auto yaxs   = simd_make_float3(0.0f, 2.0f, 0.0f);
      auto zaxs   = simd_make_float3(0.0f, 0.0f, 2.0f);
      xaxs        = simd_act(padState_.posture, xaxs) + center;
      yaxs        = simd_act(padState_.posture, yaxs) + center;
      zaxs        = simd_act(padState_.posture, zaxs) + center;
      ctx.DrawLine3D(center, xaxs, {1.0f, 0.0f, 0.0f, 1.0f});
      ctx.DrawLine3D(center, yaxs, {0.0f, 1.0f, 0.0f, 1.0f});
      ctx.DrawLine3D(center, zaxs, {0.0f, 0.0f, 1.0f, 1.0f});
    }

    if (!sprite_)
    {
      sprite_ = ctx.CreateSprite("images/szlogo.png");
    }
    ctx.DrawSprite(sprite_);

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
