# =======================================================================================================================
# Project Build Options and Variables
#
# Overview:
#   This module defines standard CMake build options and project-specific variables that control
#   the compilation process, such as build type, library type (shared/static), and whether to
#   build examples or tests.
#
# |---------------------------|---------------------|-----------------------------------------------|---------------------------------------------------------------|
# | Variable / Option         | Availability        | Default                                       | Description                                                   |
# |===========================|=====================|===============================================|===============================================================|
# | CMAKE_BUILD_TYPE          | Always              | "Debug" (if not set)                          | Standard CMake: Debug, Release, MinSizeRel, RelWithDebInfo.   |
# | FSM_BUILD_DEBUG           | Always (Derived)    | ON (for Debug, RelWithDebInfo), OFF otherwise | Internal flag for debug builds.                               |
# | FSM_BUILD_SHARED          | Always (Option)     | OFF                                           | Build shared libraries if ON, static if OFF.                  |
# | FSM_BUILD_EXAMPLE         | Top-Level (Option)  | OFF                                           | Build example programs.                                       |
# |---------------------------|---------------------|-----------------------------------------------|---------------------------------------------------------------|
#
# =======================================================================================================================
# 项目构建选项和变量
#
# 概述：
#   本模块定义了标准的 CMake 构建选项和项目特定的变量，这些选项和变量控制
#   编译过程，例如构建类型、库类型（共享/静态）以及是否构建示例或测试。
#
# |---------------------------|---------------------|-----------------------------------------------|---------------------------------------------------------------|
# | Variable / Option         | Availability        | Default                                       | Description                                                   |
# |===========================|=====================|===============================================|===============================================================|
# | CMAKE_BUILD_TYPE          | 总是                | "Debug" (如果未设置)                          | 标准 CMake 变量：Debug, Release, MinSizeRel, RelWithDebInfo。 |
# | FSM_BUILD_DEBUG           | 总是 (派生)         | ON (对应 Debug, RelWithDebInfo), OFF (其他)   | 内部标志，用于调试构建。                                      |
# | FSM_BUILD_SHARED          | 总是 (选项)         | OFF                                           | 如果为 ON 构建共享库，为 OFF 构建静态库。                     |
# | FSM_BUILD_EXAMPLE         | 顶层项目 (选项)     | OFF                                           | 构建示例程序。                                                |
# |---------------------------|---------------------|-----------------------------------------------|---------------------------------------------------------------|

if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE Debug)
	set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()
if(("${CMAKE_BUILD_TYPE}" STREQUAL "Debug") # For debugging purposes, includes symbol table and unoptimized code (-O0 -g)
	OR ("${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo")) # Includes optimized code and symbol table for debugging when errors occur (-O2 -g -DNDEBUG)
	set(FSM_BUILD_DEBUG ON)
elseif(("${CMAKE_BUILD_TYPE}" STREQUAL "Release") # For release purposes, includes optimized code and typically does not include symbol table (-O3 -DNDEBUG)
	OR ("${CMAKE_BUILD_TYPE}" STREQUAL "MinSizeRel")) # Minimizes binary size, enables optimizations, and removes unnecessary symbols (-Os -DNDEBUG)
	set(FSM_BUILD_DEBUG OFF)
else()
	message(FATAL_ERROR "Unsupported build type: ${CMAKE_BUILD_TYPE}.")
endif()

option(FSM_BUILD_SHARED "build shared library" ON)
mark_as_advanced(FSM_BUILD_SHARED)
if(FSM_BUILD_SHARED)
    set(FSM_LIB_TYPE SHARED)
    set(FSM_LIB_NAME shared)
else()
    set(FSM_LIB_TYPE STATIC)
    set(FSM_LIB_NAME static)
endif()

if(PROJECT_IS_TOP_LEVEL)
    option(FSM_BUILD_EXAMPLE "build example program" OFF)
endif()
