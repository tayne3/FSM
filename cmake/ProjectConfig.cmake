set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

include(GNUInstallDirs)
set(CMAKE_SKIP_BUILD_RPATH OFF)
set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH OFF)
if(APPLE)
    set(CMAKE_MACOSX_RPATH ON)
    set(CMAKE_INSTALL_RPATH "@loader_path;@loader_path/${CMAKE_INSTALL_LIBDIR}")
else()
    set(CMAKE_INSTALL_RPATH "$ORIGIN;$ORIGIN/${CMAKE_INSTALL_LIBDIR}")
endif()

if(PROJECT_IS_TOP_LEVEL)
	find_program(CCACHE_PROGRAM ccache)
	if(CCACHE_PROGRAM)
		set(CMAKE_C_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
		set(CMAKE_CXX_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
	endif()
endif()

add_library(${PROJECT_NAME}_compile_dependency INTERFACE)
target_compile_features(${PROJECT_NAME}_compile_dependency INTERFACE c_std_99)
if(CMAKE_BUILD_TYPE)
	if(PROJECT_BUILD_DEBUG)
		target_compile_definitions(${PROJECT_NAME}_compile_dependency INTERFACE -DDEBUG)
	else()
		target_compile_definitions(${PROJECT_NAME}_compile_dependency INTERFACE -DNDEBUG)
	endif()
endif()

# set source charset to utf-8 for MSVC
if(CMAKE_C_COMPILER_ID STREQUAL "MSVC")
    target_compile_options(${PROJECT_NAME}_compile_dependency INTERFACE 
		"$<$<COMPILE_LANGUAGE:C>:/utf-8>"
	)
endif()
if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    target_compile_options(${PROJECT_NAME}_compile_dependency INTERFACE 
		"$<$<COMPILE_LANGUAGE:CXX>:/utf-8>"
	)
endif()

# compiler warnings, skipped for MSVC & ClangCL (MSVC frontend)
if(NOT (CMAKE_C_COMPILER_ID STREQUAL "MSVC" OR ("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang" AND "${CMAKE_C_COMPILER_FRONTEND_VARIANT}" STREQUAL "MSVC")))
    target_compile_options(${PROJECT_NAME}_compile_dependency INTERFACE
        "$<$<COMPILE_LANGUAGE:C>:-Wall>"
        "$<$<COMPILE_LANGUAGE:C>:-Wextra>"
        "$<$<COMPILE_LANGUAGE:C>:-Werror=return-type>"
    )
endif()
if(NOT (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" OR ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang" AND "${CMAKE_CXX_COMPILER_FRONTEND_VARIANT}" STREQUAL "MSVC")))
    target_compile_options(${PROJECT_NAME}_compile_dependency INTERFACE
        "$<$<COMPILE_LANGUAGE:CXX>:-Wall>"
        "$<$<COMPILE_LANGUAGE:CXX>:-Wextra>"
        "$<$<COMPILE_LANGUAGE:CXX>:-Werror=return-type>"
    )
endif()

# Handle -Wno-missing-field-initializers for older GCC
if(CMAKE_C_COMPILER_ID STREQUAL "GNU" AND CMAKE_C_COMPILER_VERSION VERSION_LESS 6.0)
    target_compile_options(${PROJECT_NAME}_compile_dependency INTERFACE 
		"$<$<COMPILE_LANGUAGE:C>:-Wno-missing-field-initializers>"
	)
endif()
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 6.0)
    target_compile_options(${PROJECT_NAME}_compile_dependency INTERFACE 
		"$<$<COMPILE_LANGUAGE:CXX>:-Wno-missing-field-initializers>"
	)
endif()
