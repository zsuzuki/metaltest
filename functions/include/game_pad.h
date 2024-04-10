//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#pragma once

#include <cinttypes>

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
  Button shoulderL;
  Button shoulderR;
  Button buttonMenu;
  Button buttonOptions;
  float  leftX;
  float  leftY;
  float  rightX;
  float  rightY;
  float  triggerL;
  float  triggerR;

  void updateRepeat(Button &btn);

private:
  int     repeatCount_  = 0;
  Button *repeatButton_ = nullptr;
};

//
bool GetPadState(int idx, PadState &state);

} // namespace GamePad
