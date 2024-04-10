#
# Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
#
cmake_minimum_required(VERSION 3.21)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(src
  simple2d.metal
  simple3d.metal
  prim2d.metal
  prim3d.metal
)

set(shaderfiles "")
foreach(FILE ${src})
  get_filename_component(FILE_WE ${FILE} NAME_WE)
  set(INFILE ${CMAKE_SOURCE_DIR}/shaders/${FILE})
  set(OUTFILE ${FILE_WE}.ir)
  add_custom_command(OUTPUT ${OUTFILE}
                     COMMAND xcrun -sdk macosx metal -o ${OUTFILE} -c ${INFILE}
                     MAIN_DEPENDENCY ${INFILE}
                     COMMENT "metal shader ${FILE}"
                     VERBATIM)
  list(APPEND shaderfiles ${OUTFILE})
endforeach(FILE)

add_custom_command(OUTPUT shaders.metallib
  COMMAND xcrun -sdk macosx metallib -o shaders.metallib ${shaderfiles}
  DEPENDS ${shaderfiles}
  COMMENT "Link shaders"
)

add_custom_target(
  shaders ALL
  DEPENDS shaders.metallib
  COMMENT "Building shader"
)
