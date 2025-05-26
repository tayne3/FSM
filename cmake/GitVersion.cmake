# GitVersion.cmake - CMake module for Git-based version management
# ===========================================
# See https://github.com/tayne3/GitVersion.cmake for usage and update instructions.
#
# MIT License
# -----------
#[[
  Copyright (c) 2025 tayne3 and contributors

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
]]

if(DEFINED _GITVERSION_INCLUDED)
  return()
endif()
set(_GITVERSION_INCLUDED TRUE)
cmake_minimum_required(VERSION 3.12)

# Find Git executable
find_package(Git QUIET)

# Main function that extracts version information from Git tags
#
# Usage:
# gitversion_extract(
#   [VERSION <out-var>]               # Output variable for version string (e.g. "1.2.3")
#   [FULL_VERSION <out-var>]          # Output variable for full version with dev info if applicable
#   [MAJOR <out-var>]                 # Output variable for major version
#   [MINOR <out-var>]                 # Output variable for minor version
#   [PATCH <out-var>]                 # Output variable for patch version
#   [DEFAULT_VERSION <version>]       # Default version if no Git tag is found (default: "0.0.0")
#   [SOURCE_DIR <dir>]                # Source directory to search for Git info (default: CMAKE_CURRENT_SOURCE_DIR)
#   [HASH_LENGTH <length>]            # Length of the git commit hash to include (default: 7)
#   [FAIL_ON_MISMATCH]                # Fail if Git tag version doesn't match DEFAULT_VERSION
# )
function(gitversion_extract)
  # Parse arguments
  set(options FAIL_ON_MISMATCH)
  set(oneValueArgs VERSION FULL_VERSION MAJOR MINOR PATCH DEFAULT_VERSION SOURCE_DIR HASH_LENGTH)
  cmake_parse_arguments(GV "${options}" "${oneValueArgs}" "" ${ARGN})
  
  # Validate input parameters
  if(NOT GV_VERSION AND NOT GV_FULL_VERSION AND NOT GV_MAJOR AND NOT GV_MINOR AND NOT GV_PATCH)
    message(FATAL_ERROR "At least one output parameter (VERSION, FULL_VERSION, MAJOR, MINOR, or PATCH) is required.")
    return()
  endif()
  
  # Set default values for optional parameters
  if(NOT DEFINED GV_SOURCE_DIR)
    set(GV_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()
  
  # Set default hash length if not specified or invalid
  if(NOT DEFINED GV_HASH_LENGTH OR GV_HASH_LENGTH EQUAL 0)
    set(GV_HASH_LENGTH 7)
  elseif(GV_HASH_LENGTH GREATER 40 OR GV_HASH_LENGTH LESS 0)
    set(GV_HASH_LENGTH 40)
  endif()
  
  # Validate default version format
  if(NOT DEFINED GV_DEFAULT_VERSION)
    set(GV_DEFAULT_VERSION "0.0.0")
    set(VERSION_MAJOR 0)
    set(VERSION_MINOR 0)
    set(VERSION_PATCH 0)
  elseif(GV_DEFAULT_VERSION MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
    set(VERSION_MAJOR "${CMAKE_MATCH_1}")
    set(VERSION_MINOR "${CMAKE_MATCH_2}")
    set(VERSION_PATCH "${CMAKE_MATCH_3}")
  else()
    message(FATAL_ERROR "Default version '${GV_DEFAULT_VERSION}' does not follow semver format (MAJOR.MINOR.PATCH).")
  endif()
  
  # Initialize version strings
  set(VERSION_SHORT "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
  set(VERSION_FULL "${VERSION_SHORT}")

  # State variables
  set(IS_TAG_AVAILABLE FALSE)
  set(IS_DEVELOPMENT_VERSION FALSE)

  # Verify Git is available
  if(NOT GIT_FOUND)
    message(STATUS "Git executable not found, using default version ${GV_DEFAULT_VERSION}.")
  elseif(NOT EXISTS "${GV_SOURCE_DIR}/.git")
    message(STATUS "Directory '${GV_SOURCE_DIR}' is not a git repository, using default version ${GV_DEFAULT_VERSION}.")
  else()
    # Execute git describe command
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" -C "${GV_SOURCE_DIR}" describe --match *.*.* --tags --abbrev=${GV_HASH_LENGTH}
      RESULT_VARIABLE GIT_RESULT
      OUTPUT_VARIABLE GIT_DESCRIBE_OUTPUT
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_VARIABLE GIT_ERROR_OUTPUT
      ERROR_STRIP_TRAILING_WHITESPACE
    )
    
    if(GIT_RESULT EQUAL 0)
      # Set configuration dependency on Git HEAD so CMake reconfigures when commits are made
      set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${GV_SOURCE_DIR}/.git/HEAD")

      # Construct regex for parsing the Git output 
      set(REGEX_VERSION_TAG "^v?([0-9]+\\.[0-9]+\\.[0-9]+)$")
      set(REGEX_VERSION_DEV "^v?([0-9]+\\.[0-9]+\\.[0-9]+)-([0-9]+)-g([a-f0-9]+)$")
      
      # Parse git describe output
      if(GIT_DESCRIBE_OUTPUT MATCHES "${REGEX_VERSION_TAG}")
        # Exact tagged release version
        set(IS_TAG_AVAILABLE TRUE)
        set(GIT_TAG_VERSION ${CMAKE_MATCH_1})
      elseif(GIT_DESCRIBE_OUTPUT MATCHES "${REGEX_VERSION_DEV}")
        # Untagged development version (commits after the tag)
        set(IS_TAG_AVAILABLE TRUE)
        set(IS_DEVELOPMENT_VERSION TRUE)
        set(GIT_TAG_VERSION ${CMAKE_MATCH_1})
        set(GIT_COMMITS_COUNT ${CMAKE_MATCH_2})
        set(GIT_COMMIT_HASH ${CMAKE_MATCH_3})
      else()
        message(WARNING "Failed to parse version from git describe output: '${GIT_DESCRIBE_OUTPUT}'")
      endif()
    else()
      message(WARNING "Git describe command failed with error: ${GIT_ERROR_OUTPUT}")
    endif()
  endif()

  # Process the version information
  if(IS_TAG_AVAILABLE)
    # Parse the components of the version
    if(GIT_TAG_VERSION MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
      set(VERSION_MAJOR "${CMAKE_MATCH_1}")
      set(VERSION_MINOR "${CMAKE_MATCH_2}")
      set(VERSION_PATCH "${CMAKE_MATCH_3}")
    endif()
    
    if(NOT IS_DEVELOPMENT_VERSION)
      # For release versions (exact tags)
      if(GV_FAIL_ON_MISMATCH AND NOT GV_DEFAULT_VERSION VERSION_EQUAL GIT_TAG_VERSION)
        message(SEND_ERROR "Project version (${GV_DEFAULT_VERSION}) does not match Git tag (${GIT_TAG_VERSION}).")
      endif()
      set(VERSION_FULL "${GIT_TAG_VERSION}")
    else()
      # For development versions (with commits after tag)
      if(GV_FAIL_ON_MISMATCH AND NOT GV_DEFAULT_VERSION VERSION_GREATER_EQUAL GIT_TAG_VERSION)
        message(SEND_ERROR "Project version (${GV_DEFAULT_VERSION}) must be at least equal to tagged ancestor (${GIT_TAG_VERSION}).")
      endif()
      # Format according to SemVer 2.0.0 for pre-release versions with build metadata
      set(VERSION_FULL "${GIT_TAG_VERSION}-dev.${GIT_COMMITS_COUNT}+${GIT_COMMIT_HASH}")
    endif()
    set(VERSION_SHORT "${GIT_TAG_VERSION}")
  endif()

  # Set output variables in parent scope
  if(GV_VERSION)
    set(${GV_VERSION} "${VERSION_SHORT}" PARENT_SCOPE)
  endif()
  if(GV_FULL_VERSION)
    set(${GV_FULL_VERSION} "${VERSION_FULL}" PARENT_SCOPE)
  endif()
  if(GV_MAJOR)
    set(${GV_MAJOR} "${VERSION_MAJOR}" PARENT_SCOPE)
  endif()
  if(GV_MINOR)
    set(${GV_MINOR} "${VERSION_MINOR}" PARENT_SCOPE)
  endif()
  if(GV_PATCH)
    set(${GV_PATCH} "${VERSION_PATCH}" PARENT_SCOPE)
  endif()
endfunction()
