cmake_minimum_required(VERSION 3.21)

set(APP_NAME "SwiftUnaExample")
set(APP_USER_NAME "MTB Logger")
set(APP_TYPE "Glance")
set(DEV_ID "UNA")
set(APP_ID "E87D0A49F3B15C62")
set(APP_USE_ICONS Off)

set(ENV{UNA_SDK} "${CMAKE_CURRENT_SOURCE_DIR}/una-sdk")
if(NOT EXISTS "$ENV{UNA_SDK}/cmake/una-app.cmake")
    message(FATAL_ERROR "UNA SDK submodule missing. Run: git submodule update --init")
endif()
if(NOT DEFINED UNA_PYTHON_EXECUTABLE)
    find_program(UV uv REQUIRED)
    set(UNA_PYTHON_EXECUTABLE "${CMAKE_CURRENT_SOURCE_DIR}/Scripts/python")
endif()

include($ENV{UNA_SDK}/cmake/una-app.cmake)
include($ENV{UNA_SDK}/cmake/una-sdk.cmake)
project(${APP_NAME})

if(NOT DEFINED SWIFTC AND DEFINED ENV{SWIFTC})
    set(SWIFTC "$ENV{SWIFTC}")
endif()
find_program(SWIFTC swiftc REQUIRED)
execute_process(COMMAND ${SWIFTC} -version
    OUTPUT_VARIABLE SWIFT_VERSION ERROR_VARIABLE SWIFT_VERSION_ERROR)
if(NOT "${SWIFT_VERSION}${SWIFT_VERSION_ERROR}" MATCHES "Swift version 6\\.4")
    message(FATAL_ERROR "Swift 6.4 required: ${SWIFT_VERSION}${SWIFT_VERSION_ERROR}")
endif()
execute_process(COMMAND ${SWIFTC} -print-target-info
    -target armv8m.main-none-none-eabi -enable-experimental-feature Embedded
    OUTPUT_VARIABLE SWIFT_TARGET_INFO)
string(JSON SWIFT_EMBEDDED_PATH GET "${SWIFT_TARGET_INFO}" paths runtimeLibraryPaths 0)
if(NOT EXISTS "${SWIFT_EMBEDDED_PATH}")
    message(FATAL_ERROR "Swift 6.4 Embedded standard library missing: ${SWIFT_EMBEDDED_PATH}. Install a Swift 6.4 toolchain with bare-metal Embedded Swift support and select its swiftc on PATH.")
endif()

set(SWIFT_OBJECT ${CMAKE_CURRENT_BINARY_DIR}/RideSample.o)
add_custom_command(OUTPUT ${SWIFT_OBJECT}
    COMMAND ${SWIFTC} -target armv8m.main-none-none-eabi
        -enable-experimental-feature Embedded -wmo -Osize
        -Xfrontend -function-sections -Xfrontend -disable-stack-protector
        -Xcc -mcpu=cortex-m33 -Xcc -mfpu=fpv5-sp-d16 -Xcc -mfloat-abi=hard
        -parse-as-library -emit-object
        ${CMAKE_CURRENT_SOURCE_DIR}/Sources/RideSample.swift
        -o ${SWIFT_OBJECT}
    DEPENDS Sources/RideSample.swift
    VERBATIM)
set_source_files_properties(${SWIFT_OBJECT} PROPERTIES EXTERNAL_OBJECT TRUE GENERATED TRUE)

set(BUILD_VERSION "1.0.0")
set(SERVICE_SOURCES
    Sources/Service.cpp
    Sources/RideLogger.cpp
    Sources/RideFitWriter.cpp
    ${SWIFT_OBJECT}
    ${UNA_SDK_SOURCES_COMMON}
    ${UNA_SDK_SOURCES_SENSOR}
    ${UNA_SDK_SOURCES_FIT}
    ${UNA_SDK_SOURCES_APPSYSTEM})
set(SERVICE_INCLUDE_DIRS
    Sources
    ${UNA_SDK_INCLUDE_DIRS_COMMON}
    ${UNA_SDK_INCLUDE_DIRS_SERVICE})
una_app_build_service(${APP_NAME}Service.elf)

una_app_build_app()
