//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#pragma once

#include <cinttypes>
#include <simd/simd.h>

namespace GamePad
{

//
//
//
class PadState
{
public:
  class Button
  {
    bool press_;
    bool prev_;
    bool repeat_;

  public:
    Button() : press_(false), prev_(false) {}
    explicit Button(bool swon, bool prev) : press_(swon), prev_(prev) {}
    Button(const Button &other) = default;
    Button(Button &&other)      = delete;
    ~Button()                   = default;

    Button &operator=(const Button &) = default;
    Button &operator=(Button &&)      = delete;

    void updateRepeat(int &count, Button *&repBtn);
    void overridePress(bool press = true) { press_ = press ? true : press_; }

    [[nodiscard]] bool Pressed() const { return press_; }
    [[nodiscard]] bool On() const { return press_ && !prev_; }
    [[nodiscard]] bool Release() const { return !press_ && prev_; }
    [[nodiscard]] bool Repeat() const { return On() || repeat_; }
  };

  bool   enabled_;
  Button buttonUp;
  Button buttonDown;
  Button buttonLeft;
  Button buttonRight;
  Button buttonA;
  Button buttonB;
  Button buttonC;
  Button buttonD;
  Button thumbL;
  Button thumbR;
  Button shoulderL;
  Button shoulderR;
  Button buttonMenu;
  Button buttonOptions;
  Button buttonTouch;
  float  leftX;
  float  leftY;
  float  rightX;
  float  rightY;
  float  triggerL;
  float  triggerR;

  simd_float3 acceleration;
  simd_float3 rotation;
  simd_quatf  posture;

  void updateRepeat(Button &btn);

private:
  int     repeatCount_  = 0;
  Button *repeatButton_ = nullptr;
};

//
bool GetPadState(int idx, PadState &state);

} // namespace GamePad
