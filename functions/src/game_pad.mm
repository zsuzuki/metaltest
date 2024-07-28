//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#import "game_pad.h"
#import <GameController/GameController.h>

namespace GamePad
{
constexpr int RepeatCountInit = 30;
constexpr int RepeatCountCont = 5;

void PadState::Button::updateRepeat(int &count, PadState::Button *&repBtn)
{
  repeat_ = false;

  if (press_)
  {
    if (!prev_)
    {
      // start repeat
      repBtn = this;
      count  = RepeatCountInit;
    }
    else if (repBtn == this)
    {
      if (count > 0)
      {
        count--;
      }
      else
      {
        repeat_ = true;
        count   = RepeatCountCont;
      }
    }
  }
}

void PadState::updateRepeat(Button &btn) { btn.updateRepeat(repeatCount_, repeatButton_); }

//
//
//
bool GetPadState(int idx, PadState &state)
{
  auto const padArray = [GCController controllers];

  if (idx < 0 || idx >= padArray.count)
  {
    state.enabled_ = false;
    return false;
  }

  auto pad   = padArray[idx];
  auto input = [pad extendedGamepad];
  if (input == nullptr)
  {
    state.enabled_ = false;
    return false;
  }

  state.enabled_   = true;
  auto setupButton = [&](PadState::Button &btn, GCControllerButtonInput *src)
  {
    const PadState::Button newState{src.isPressed, btn.Pressed()};
    btn = newState;
    state.updateRepeat(btn);
  };
  setupButton(state.buttonMenu, input.buttonMenu);
  setupButton(state.buttonOptions, input.buttonOptions);
  setupButton(state.buttonA, input.buttonA);
  setupButton(state.buttonB, input.buttonB);
  setupButton(state.buttonC, input.buttonX);
  setupButton(state.buttonD, input.buttonY);
  setupButton(state.shoulderL, input.leftShoulder);
  setupButton(state.shoulderR, input.rightShoulder);
  setupButton(state.buttonUp, input.dpad.up);
  setupButton(state.buttonDown, input.dpad.down);
  setupButton(state.buttonLeft, input.dpad.left);
  setupButton(state.buttonRight, input.dpad.right);
  setupButton(state.thumbL, input.leftThumbstickButton);
  setupButton(state.thumbR, input.rightThumbstickButton);

  auto analogValue = [](float value)
  {
    constexpr float lim   = 0.1f;
    constexpr float range = 1.0f - lim;
    return value > lim ? (value - lim) / range : value < -lim ? (value + lim) / range : 0.0f;
  };
  auto lStick    = input.leftThumbstick;
  auto rStick    = input.rightThumbstick;
  state.leftX    = analogValue(lStick.xAxis.value);
  state.leftY    = analogValue(lStick.yAxis.value);
  state.rightX   = analogValue(rStick.xAxis.value);
  state.rightY   = analogValue(rStick.yAxis.value);
  state.triggerL = analogValue(input.leftTrigger.analog ? input.leftTrigger.value : 0.0f);
  state.triggerR = analogValue(input.rightTrigger.analog ? input.rightTrigger.value : 0.0f);

  return true;
}

} // namespace GamePad
