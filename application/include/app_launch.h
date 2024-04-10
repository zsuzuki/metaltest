//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#pragma once

#include <functional>
#include <memory>

//
class ApplicationLoop
{
public:
  ApplicationLoop()          = default;
  virtual ~ApplicationLoop() = default;

  // main update loop
  virtual void Update() {}
};

//
void LaunchApplication(std::shared_ptr<ApplicationLoop> apploop);

//
