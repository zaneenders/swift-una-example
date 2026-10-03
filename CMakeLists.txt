cmake_minimum_required(VERSION 3.21)

set(APP_NAME "SwiftUnaExample")
set(APP_USER_NAME "MTB Logger")
set(APP_FILE_NAME "SwiftUnaExample")
set(APP_TYPE "Activity")
set(DEV_ID "UNA")
set(APP_ID "E87D0A49F3B15C62")
set(APP_USE_ICONS On)

set(ENV{UNA_SDK} "${CMAKE_CURRENT_SOURCE_DIR}/una-sdk")
if(NOT EXISTS "$ENV{UNA_SDK}/cmake/una-app.cmake")
    message(FATAL_ERROR "UNA SDK submodule missing. Run: git submodule update --init")
endif()
if(NOT DEFINED UNA_PYTHON_EXECUTABLE)
    find_program(UV uv REQUIRED)
    set(UNA_PYTHON_EXECUTABLE "${CMAKE_CURRENT_SOURCE_DIR}/Scripts/python")
endif()

set(CMAKE_TOOLCHAIN_FILE "$ENV{UNA_SDK}/cmake/toolchain-arm-none-eabi.cmake")
project(${APP_NAME} LANGUAGES C CXX ASM)
include($ENV{UNA_SDK}/cmake/una-app.cmake)
include($ENV{UNA_SDK}/cmake/una-sdk.cmake)

# The SDK linker map has addresses but no function/Thumb symbol types.
# Preserve its ABI addresses while supplying the missing type metadata.
set(FIRMWARE_EXPORT_MAP "$ENV{UNA_SDK}/Libs/Source/AppSystem/linker/LibC/libc_exports_0.0.3.ld")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${FIRMWARE_EXPORT_MAP}")
file(STRINGS "${FIRMWARE_EXPORT_MAP}" FIRMWARE_EXPORTS)
set(FIRMWARE_SYMBOLS ".syntax unified\n.thumb\n")
foreach(EXPORT IN LISTS FIRMWARE_EXPORTS)
    if(EXPORT MATCHES "PROVIDE\\(([A-Za-z0-9_]+) = (0x[0-9A-Fa-f]+)\\)")
        string(APPEND FIRMWARE_SYMBOLS ".weak ${CMAKE_MATCH_1}\n.type ${CMAKE_MATCH_1}, %function\n.thumb_set ${CMAKE_MATCH_1}, ${CMAKE_MATCH_2}\n")
    endif()
endforeach()
string(APPEND FIRMWARE_SYMBOLS ".section .note.GNU-stack,\"\",%progbits\n")
set(FIRMWARE_SYMBOL_FILE "${CMAKE_CURRENT_BINARY_DIR}/FirmwareSymbols.s")
file(WRITE "${FIRMWARE_SYMBOL_FILE}" "${FIRMWARE_SYMBOLS}")

if(NOT DEFINED SWIFTC AND DEFINED ENV{SWIFTC})
    set(SWIFTC "$ENV{SWIFTC}")
endif()
find_program(SWIFTC swiftc REQUIRED)
find_program(ARM_OBJCOPY arm-none-eabi-objcopy REQUIRED)
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
    # Compiler module fingerprint is not runtime data and is not packaged by UNA.
    COMMAND ${ARM_OBJCOPY} --remove-section=.swift_modhash ${SWIFT_OBJECT}
    DEPENDS Sources/RideSample.swift
    VERBATIM)
set_source_files_properties(${SWIFT_OBJECT} PROPERTIES EXTERNAL_OBJECT TRUE GENERATED TRUE)

set(BUILD_VERSION "1.0.0")
set(SERVICE_SOURCES
    ${FIRMWARE_SYMBOL_FILE}
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
# Swift emits int-sized enum metadata; SDK libraries use variable-sized enums.
# No enums cross SwiftBridge.hpp: only fixed-width scalars and pointers.
target_link_options(${APP_NAME}Service.elf PRIVATE -Wl,--no-enum-size-warning -Wl,-z,noexecstack)

set(GUI_SOURCES
    ${FIRMWARE_SYMBOL_FILE}
    Sources/Gui.cpp
    ${UNA_SDK_SOURCES_COMMON}
    ${CMAKE_CURRENT_SOURCE_DIR}/una-sdk/Libs/Source/AppSystem/EntryPoint/CustomGUI/main.cpp)
set(GUI_INCLUDE_DIRS Sources ${UNA_SDK_INCLUDE_DIRS_COMMON} ${UNA_SDK_INCLUDE_DIRS_SERVICE})
una_app_build_gui(${APP_NAME}GUI.elf)
target_link_options(${APP_NAME}GUI.elf PRIVATE -Wl,-z,noexecstack)

una_app_build_app()
