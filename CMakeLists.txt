cmake_minimum_required(VERSION 3.14)

include(cmake/PreventInSourceBuilds.cmake)
include(cmake/GitVersion.cmake)
gitversion_extract(VERSION PROJECT_VERSION DEFAULT_VERSION 0.1.0)
project(FSM VERSION ${PROJECT_VERSION})

include(cmake/ProjectIsTopLevel.cmake)
include(cmake/OptionVariables.cmake)
include(cmake/ProjectConfig.cmake)

file(GLOB_RECURSE fsm_source_files CONFIGURE_DEPENDS src/*.c src/*.cpp src/*.cc src/*.h src/*.hpp)
add_library(fsm ${FSM_LIB_TYPE} ${fsm_source_files})
target_include_directories(fsm PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_definitions(fsm PRIVATE ${FSM_COMPILE_DEFINITIONS})
target_compile_features(fsm PRIVATE c_std_99 cxx_std_11)
set_target_properties(fsm PROPERTIES OUTPUT_NAME fsm)

add_library(fsm::fsm ALIAS fsm)
add_library(fsm::${FSM_LIB_NAME} ALIAS fsm)
message(STATUS "FSM ${PROJECT_VERSION} ${FSM_LIB_NAME} library")

if(FSM_BUILD_EXAMPLE)
    add_subdirectory(example)
endif()
