#
# Copyright 2024 Y.Suzuki(wave.suzuki.z@gmail.com)
#
cmake_minimum_required(VERSION 3.21)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

project(metaltest)

include_directories(include)
#include_directories(application/include)
# include_directories(functions/include)
include_directories(shaders)

set(SOURCES
    src/main.cpp
)

add_subdirectory(shaders)
add_subdirectory(application)
add_subdirectory(functions)

add_executable(${PROJECT_NAME} ${SOURCES} shaders)
target_link_libraries(${PROJECT_NAME}
    PRIVATE
        application
        functions
        "-framework Metal"
        "-framework Cocoa"
        "-framework CoreGraphics"
        "-framework MetalKit"
        "-framework GameController"
        "-framework CoreText"
        "-framework CoreImage"
        "-framework Foundation"
    )

#
set(SHADERS_LIB ${CMAKE_BINARY_DIR}/shaders/shaders.metallib)

set(resources_files
  resources/images/szlogo.png
)

#
set(RESOURCE_FILES
    ${SHADERS_LIB}
    ${resources_files}
)

set_target_properties(${PROJECT_NAME} PROPERTIES
  MACOSX_BUNDLE TRUE
  MACOSX_FRAMEWORK_IDENTIFIER org.suzukiz.${PROJECT_NAME}
  RESOURCE "${RESOURCE_FILES}"
)

foreach(RFILES ${resources_files})
  file(RELATIVE_PATH fname "${CMAKE_CURRENT_SOURCE_DIR}/resources" "${CMAKE_CURRENT_SOURCE_DIR}/${RFILES}")
  get_filename_component(fdir ${fname} DIRECTORY)
  set_source_files_properties(${RFILES} PROPERTIES MACOSX_PACKAGE_LOCATION "Resources/${fdir}")
  add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_CURRENT_SOURCE_DIR}/${RFILES}
        $<TARGET_FILE_DIR:${PROJECT_NAME}>/../Resources/${fname}
    COMMENT "COPY: ${RFILES}"
  )
  set_property(TARGET ${PROJECT_NAME}
    APPEND PROPERTY ADDITIONAL_CLEAN_FILES ${PROJECT_NAME}.app/Contents/Resources/${fdir}
  )
endforeach(RFILES ${resources_files})

#
# Shaders build
#
set_source_files_properties(${SHADERS_LIB} PROPERTIES MACOSX_PACKAGE_LOCATION "Resources/shaders")
# シェーダーライブラリのコピー
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${SHADERS_LIB}
        $<TARGET_FILE_DIR:${PROJECT_NAME}>/../Resources/shaders/shaders.metallib
    DEPENDS ${CMAKE_BINARY_DIR}/shaders/shaders.metallib
    COMMENT "COPY: Shader Library"
)
# clean対象にする
set_property(TARGET ${PROJECT_NAME}
  APPEND PROPERTY ADDITIONAL_CLEAN_FILES ${PROJECT_NAME}.app/Contents/Resources/shaders
)
set_property(TARGET ${PROJECT_NAME}
  APPEND PROPERTY ADDITIONAL_CLEAN_FILES ${CMAKE_BINARY_DIR}/shaders
)
# Shaders build
