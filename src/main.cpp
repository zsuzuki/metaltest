//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#include <_time.h>
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
#include <mutex>
#include <simd/quaternion.h>
#include <simd/vector_make.h>
#include <sprite4cpp.h>
#include <time.h>

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
  GamePad::PadState padStateUpdate_{};
  bool              onKeyW_      = false;
  bool              onKeyA_      = false;
  bool              onKeyS_      = false;
  bool              onKeyD_      = false;
  uint64_t          updateCount_ = 0;

  std::shared_ptr<SpriteCpp> sprite_;

  std::mutex padLock_;

  uint64_t connectTime_;
  uint64_t lastUpdateTime_;

public:
  MainLoop()           = default;
  ~MainLoop() override = default;

  bool InitialWindowSize(double &width, double &height, bool &border) override
  {
    std::cout << std::format("Default window size: {} x {}\n", width, height);
    width  = WindowWidth;
    height = WindowHeight;

    GamePad::InitGamePad(
        [&](const GamePad::PadState &state, GamePad::UpdateType type)
        {
          if (type == GamePad::UpdateType::PadState)
          {
            auto nowTime = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
            if (!updateCount_)
            {
              connectTime_ = lastUpdateTime_ = nowTime;
            }
            else if ((nowTime - lastUpdateTime_) > (1000 * 1000 * 1000))
            {
              connectTime_ = lastUpdateTime_ = nowTime;
              updateCount_                   = 0;
            }
            else
            {
              lastUpdateTime_ = nowTime;
            }
            updateCount_++;
          }
          std::lock_guard guard{padLock_};
          padState_ = state;
        },
        [&](uint64_t hash)
        {
          updateCount_ = 0;
          std::cout << std::format("Connect GamePad: {:x}\n", hash);
        },
        [&](uint64_t hash)
        {
          if (padState_.checkHash(hash))
          {
            padState_.enabled = false;
            updateCount_      = 0;
            std::cout << std::format("Disconnect GamePad: {:x}\n", hash);
          }
        });

    return true;
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

    if (updateCount_ > 10)
    {
      auto diffTime  = lastUpdateTime_ - connectTime_;
      auto secNum    = diffTime / (1000.0 * 1000.0 * 1000.0);
      auto upRate    = (double)updateCount_ / secNum;
      auto upRateStr = std::format("{:.3f}/{}/{:.1f}", upRate, updateCount_, secNum);
      ctx.Print(upRateStr.c_str(), 200, 240);
    }

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

    auto &pad = padStateUpdate_;
    {
      std::lock_guard guard{padLock_};
      padState_.fetch(pad);
    }

    pad.buttonUp.overridePress(onKeyW_);
    pad.buttonLeft.overridePress(onKeyA_);
    pad.buttonDown.overridePress(onKeyS_);
    pad.buttonRight.overridePress(onKeyD_);
    if (pad.enabled)
    {
      static simd_float3 tpos = simd_make_float3(0.0f, 2.0f, 0.0f);
      static float       rotY = 0.0f;
      rotY += (pad.triggerL - pad.triggerR) * 0.1f;
      auto rotQ = simd_quaternion(rotY, simd_make_float3(0.0f, 1.0f, 0.0f));
      tpos += simd_act(rotQ, simd_make_float3(-pad.leftX, 0.0f, pad.leftY)) * 0.05f;
      auto npos = vmaxq_f32(float32x4_t{tpos.x, tpos.y, tpos.z, 0.0f}, vdupq_n_f32(-8.0f));
      npos      = vminq_f32(npos, vdupq_n_f32(8.0f));
      tpos      = simd_make_float3(npos[0], npos[1], npos[2]);

      auto tp0 = simd_act(rotQ, simd_make_float3(0.0f, 0.0f, 1.0f)) + tpos;
      auto tp1 = simd_act(rotQ, simd_make_float3(1.0f, 0.0f, 0.0f)) + tpos;
      auto tp2 = simd_act(rotQ, simd_make_float3(-1.0f, 0.0f, 0.0f)) + tpos;
      ctx.DrawTriangle3D(tp0, tp1, tp2, {1, 1, 0, 1});

      std::array<bool, 11> btn{};

      auto color    = simd_make_float4(0, 1, 0, 1);
      auto drawBtns = [&](float xofs)
      {
        float y = 100;
        for (int i = 0; i < btn.size(); i++)
        {
          auto p1 = simd_make_float2(1200 + xofs, y + i * 60);
          auto p2 = simd_make_float2(1250 + xofs, y + 50 + i * 60);
          ctx.DrawRect(p1, p2, {1, 1, 1, 1});
          if (btn[i])
          {
            ctx.FillRect(p1, p2, color);
          }
        }
      };
      btn[0]  = pad.buttonA.Pressed();
      btn[1]  = pad.buttonB.Pressed();
      btn[2]  = pad.buttonC.Pressed();
      btn[3]  = pad.buttonD.Pressed();
      btn[4]  = pad.shoulderL.Pressed();
      btn[5]  = pad.shoulderR.Pressed();
      btn[6]  = pad.thumbL.Pressed();
      btn[7]  = pad.thumbR.Pressed();
      btn[8]  = pad.buttonMenu.Pressed();
      btn[9]  = pad.buttonOptions.Pressed();
      btn[10] = pad.buttonTouch.Pressed();
      drawBtns(0);
      btn[0]  = pad.buttonA.Repeat();
      btn[1]  = pad.buttonB.Repeat();
      btn[2]  = pad.buttonC.Repeat();
      btn[3]  = pad.buttonD.Repeat();
      btn[4]  = pad.shoulderL.Repeat();
      btn[5]  = pad.shoulderR.Repeat();
      btn[6]  = pad.thumbL.Repeat();
      btn[7]  = pad.thumbR.Repeat();
      btn[8]  = pad.buttonMenu.Repeat();
      btn[9]  = pad.buttonOptions.Repeat();
      btn[10] = pad.buttonTouch.Repeat();
      drawBtns(70);

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
      drawdp(pad.buttonLeft.Pressed(), 900, 500);
      drawdp(pad.buttonRight.Pressed(), 1000, 500);
      drawdp(pad.buttonUp.Pressed(), 950, 450);
      drawdp(pad.buttonDown.Pressed(), 950, 550);

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
      drawan(pad.triggerL, 650);
      drawan(pad.triggerR, 700);

      auto anbase = simd_make_float2(300, 500);
      if (pad.thumbL.Pressed())
      {
        ctx.FillPolygon(anbase, 80, 0, 20, {1.0f, 0.9f, 0.0f, 0.3f});
      }
      ctx.DrawPolygon(anbase, 100, 0, 20, {1, 1, 1, 1});
      auto an0pos = simd_make_float2(pad.leftX, -pad.leftY) * 100 + anbase;
      ctx.DrawLine(anbase, an0pos, {0, 1, 0, 1});

      anbase.x += 350;
      if (pad.thumbR.Pressed())
      {
        ctx.FillPolygon(anbase, 80, 0, 20, {1.0f, 0.9f, 0.0f, 0.3f});
      }
      ctx.DrawPolygon(anbase, 100, 0, 20, {1, 0.5, 0.5, 1});
      auto an1pos = simd_make_float2(pad.rightX, -pad.rightY) * 100 + anbase;
      ctx.DrawLine(anbase, an1pos, {0, 1, 0, 1});

      // motion
      auto center = simd_make_float3(0.0f, 5.0f, 0.0f);

      auto rot     = pad.rotation * 0.2f;
      auto motrx   = simd_quaternion(rot.x, simd_make_float3(1, 0, 0));
      auto motry   = simd_quaternion(rot.y, simd_make_float3(0, 1, 0));
      auto motrz   = simd_quaternion(rot.z, simd_make_float3(0, 0, 1));
      auto posture = simd_mul(simd_mul(motrz, motry), motrx);

      auto xaxs = simd_make_float3(2.0f, 0.0f, 0.0f);
      auto yaxs = simd_make_float3(0.0f, 2.0f, 0.0f);
      auto zaxs = simd_make_float3(0.0f, 0.0f, 2.0f);
      xaxs      = simd_act(posture, xaxs) + center;
      yaxs      = simd_act(posture, yaxs) + center;
      zaxs      = simd_act(posture, zaxs) + center;
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
