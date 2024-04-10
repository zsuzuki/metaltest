//
// Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
//
#include <app_launch.h>
#include <iostream>
#include <memory>

//
//
//
class MainLoop : public ApplicationLoop
{
public:
  MainLoop()           = default;
  ~MainLoop() override = default;

  void Update() override { std::cout << "update" << std::endl; }
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
