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
  GCExtendedGamepad *input  = Nil;
  GCMotion          *motion = Nil;

  for (GCController *controller in GCController.controllers)
  {
    if (controller.extendedGamepad)
    {
      if (idx == 0)
      {
        input = controller.extendedGamepad;
        [controller setPlayerIndex:GCControllerPlayerIndex1];
        motion = controller.motion;
        break;
      }
      else
      {
        idx--;
      }
    }
  }

  if (input == Nil)
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

  if ([input isKindOfClass:[GCDualShockGamepad class]])
  {
    GCDualShockGamepad *dualShock = (GCDualShockGamepad *)input;
    setupButton(state.buttonTouch, dualShock.touchpadButton);
  }

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

  if (motion != Nil)
  {
    auto att           = [motion attitude];
    state.posture      = simd_quaternion((float)att.x, (float)att.y, (float)att.z, (float)att.w);
    auto rot           = [motion rotationRate];
    state.rotation     = simd_make_float3(rot.x, rot.y, rot.z);
    auto acc           = [motion acceleration];
    state.acceleration = simd_make_float3(acc.x, acc.y, acc.z);

    motion.valueChangedHandler = ^(GCMotion *motion) {
      NSLog(@"Gravity: %f, %f, %f", motion.gravity.x, motion.gravity.y, motion.gravity.z);
      NSLog(@"User Acceleration: %f, %f, %f",
            motion.userAcceleration.x,
            motion.userAcceleration.y,
            motion.userAcceleration.z);
      NSLog(@"Rotation Rate: %f, %f, %f",
            motion.rotationRate.x,
            motion.rotationRate.y,
            motion.rotationRate.z);
    };
  }

  return true;
}

} // namespace GamePad
