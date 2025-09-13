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

#[[.rst:
git_version_info
----------------

Extract comprehensive version information from Git repository with modern features
including dirty state detection, enhanced SemVer 2.0.0 support, and detailed
repository status information.

Syntax:
  git_version_info(
    [VERSION <out-var>]               # Clean semantic version (e.g. "1.2.3") - suitable for CMake project()
    [FULL_VERSION <out-var>]          # Full version with metadata (e.g. "1.2.3-dev.5+abc1234.dirty")
    [MAJOR <out-var>]                 # Major version component
    [MINOR <out-var>]                 # Minor version component  
    [PATCH <out-var>]                 # Patch version component
    [COMMIT_HASH <out-var>]           # Current commit hash
    [COMMIT_COUNT <out-var>]          # Commits since last tag
    [IS_DIRTY <out-var>]              # Boolean: working directory has changes
    [IS_TAGGED <out-var>]             # Boolean: HEAD is at a tagged commit
    [IS_DEVELOPMENT <out-var>]        # Boolean: development version (commits after tag)
    [TAG_NAME <out-var>]              # Name of the current/nearest tag
    [BRANCH_NAME <out-var>]           # Current branch name
    [DEFAULT_VERSION <version>]       # Default version if no tags found (default: "0.0.0")
    [SOURCE_DIR <dir>]                # Git repository directory (default: CMAKE_CURRENT_SOURCE_DIR)
    [HASH_LENGTH <length>]            # Git hash length 1-40 (default: 7)
    [FAIL_ON_MISMATCH]                # Error if tag version != DEFAULT_VERSION
  )

Version Format Examples:
- Tagged release (clean):     1.2.3
- Tagged release (dirty):     1.2.3-dirty  
- Development (clean):        1.2.3-dev.5+abc1234
- Development (dirty):        1.2.3-dev.5+abc1234.dirty
- No tags (clean):            0.0.0+abc1234
- No tags (dirty):            0.0.0+abc1234.dirty
]]
function(git_version_info)
  # Parse function arguments
  set(options FAIL_ON_MISMATCH)
  set(oneValueArgs 
    VERSION FULL_VERSION MAJOR MINOR PATCH 
    COMMIT_HASH COMMIT_COUNT IS_DIRTY IS_TAGGED IS_DEVELOPMENT 
    TAG_NAME BRANCH_NAME
    DEFAULT_VERSION SOURCE_DIR HASH_LENGTH
  )
  cmake_parse_arguments(GV "${options}" "${oneValueArgs}" "" ${ARGN})
  
  # Input validation
  if(NOT GV_VERSION AND NOT GV_FULL_VERSION AND NOT GV_MAJOR AND NOT GV_MINOR AND NOT GV_PATCH AND
     NOT GV_COMMIT_HASH AND NOT GV_COMMIT_COUNT AND NOT GV_IS_DIRTY AND NOT GV_IS_TAGGED AND
     NOT GV_IS_DEVELOPMENT AND NOT GV_TAG_NAME AND NOT GV_BRANCH_NAME)
    message(FATAL_ERROR "git_version_info(): At least one output parameter is required.")
    return()
  endif()
  
  # Set default values
  if(NOT DEFINED GV_SOURCE_DIR)
    set(GV_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()
  
  if(NOT DEFINED GV_HASH_LENGTH OR GV_HASH_LENGTH EQUAL 0)
    set(GV_HASH_LENGTH 7)
  elseif(GV_HASH_LENGTH GREATER 40 OR GV_HASH_LENGTH LESS 1)
    set(GV_HASH_LENGTH 40)
  endif()
  
  # Parse and validate default version
  if(NOT DEFINED GV_DEFAULT_VERSION)
    set(GV_DEFAULT_VERSION "0.0.0")
  endif()
  
  if(GV_DEFAULT_VERSION MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
    set(default_major "${CMAKE_MATCH_1}")
    set(default_minor "${CMAKE_MATCH_2}")
    set(default_patch "${CMAKE_MATCH_3}")
  else()
    message(FATAL_ERROR "git_version_info(): DEFAULT_VERSION '${GV_DEFAULT_VERSION}' must follow SemVer format (MAJOR.MINOR.PATCH).")
    return()
  endif()
  
  # Initialize all output variables with defaults
  set(version_major "${default_major}")
  set(version_minor "${default_minor}")
  set(version_patch "${default_patch}")
  set(version_short "${GV_DEFAULT_VERSION}")
  set(version_full "${GV_DEFAULT_VERSION}")
  set(commit_hash "")
  set(commit_count "0")
  set(is_dirty FALSE)
  set(is_tagged FALSE)
  set(is_development FALSE)
  set(tag_name "")
  set(branch_name "")
  
  # Repository status flags  
  set(git_available FALSE)
  set(git_repo_found FALSE)
  
  # Check Git availability and repository
  if(NOT GIT_FOUND)
    message(VERBOSE "git_version_info(): Git executable not found, using default version ${GV_DEFAULT_VERSION}")
  elseif(NOT EXISTS "${GV_SOURCE_DIR}/.git")
    message(VERBOSE "git_version_info(): '${GV_SOURCE_DIR}' is not a git repository, using default version ${GV_DEFAULT_VERSION}")
  else()
    set(git_available TRUE)
    set(git_repo_found TRUE)
    
    # Set up dependency on Git files for auto-reconfiguration
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${GV_SOURCE_DIR}/.git/HEAD")
    if(EXISTS "${GV_SOURCE_DIR}/.git/index")
      set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${GV_SOURCE_DIR}/.git/index")
    endif()
  endif()
  
  if(git_available AND git_repo_found)
    # Get current commit hash
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" -C "${GV_SOURCE_DIR}" rev-parse --short=${GV_HASH_LENGTH} HEAD
      RESULT_VARIABLE git_hash_result
      OUTPUT_VARIABLE git_hash_output
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_QUIET
    )
    
    if(git_hash_result EQUAL 0)
      set(commit_hash "${git_hash_output}")
    endif()
    
    # Check for dirty working directory (staged and unstaged changes)
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" -C "${GV_SOURCE_DIR}" status --porcelain
      RESULT_VARIABLE git_status_result
      OUTPUT_VARIABLE git_status_output
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_QUIET
    )
    
    if(git_status_result EQUAL 0)
      if(git_status_output)
        set(is_dirty TRUE)
      endif()
    endif()
    
    # Get current branch name
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" -C "${GV_SOURCE_DIR}" branch --show-current
      RESULT_VARIABLE git_branch_result
      OUTPUT_VARIABLE git_branch_output
      OUTPUT_STRIP_TRAILING_WHITESPACE  
      ERROR_QUIET
    )
    
    if(git_branch_result EQUAL 0 AND git_branch_output)
      set(branch_name "${git_branch_output}")
    endif()
    
    # Get version information from tags using git describe
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" -C "${GV_SOURCE_DIR}" describe --match *.*.* --tags --abbrev=${GV_HASH_LENGTH}
      RESULT_VARIABLE git_describe_result
      OUTPUT_VARIABLE git_describe_output
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_VARIABLE git_describe_error
      ERROR_STRIP_TRAILING_WHITESPACE
    )
    
    if(git_describe_result EQUAL 0)
      # Parse git describe output
      # Patterns:
      # - v1.2.3 or 1.2.3 (exact tag)
      # - v1.2.3-5-gabcdef1 or 1.2.3-5-gabcdef1 (development version)
      
      set(regex_exact_tag "^v?([0-9]+\\.[0-9]+\\.[0-9]+)$")
      set(regex_dev_version "^v?([0-9]+\\.[0-9]+\\.[0-9]+)-([0-9]+)-g([a-f0-9]+)$")
      
      if(git_describe_output MATCHES "${regex_exact_tag}")
        # Exact tagged release
        set(is_tagged TRUE)
        set(git_tag_version "${CMAKE_MATCH_1}")
        set(tag_name "${git_describe_output}")
        
      elseif(git_describe_output MATCHES "${regex_dev_version}")  
        # Development version (commits after tag)
        set(is_development TRUE)
        set(git_tag_version "${CMAKE_MATCH_1}")
        set(commit_count "${CMAKE_MATCH_2}")
        set(tag_name "v${git_tag_version}")  # Normalize tag name
        
        # Override commit_hash from git describe if available
        if(CMAKE_MATCH_3)
          set(commit_hash "${CMAKE_MATCH_3}")
        endif()
        
      else()
        message(WARNING "git_version_info(): Cannot parse version from git describe output: '${git_describe_output}'")
      endif()
    else()
      # No tags found - this is normal for new repositories
      message(VERBOSE "git_version_info(): No version tags found in repository, using default version ${GV_DEFAULT_VERSION}")
    endif()
    
    # Process version information
    if(is_tagged OR is_development)
      # Parse version components from git tag
      if(git_tag_version MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
        set(version_major "${CMAKE_MATCH_1}")
        set(version_minor "${CMAKE_MATCH_2}")  
        set(version_patch "${CMAKE_MATCH_3}")
        set(version_short "${git_tag_version}")
        
        # Validate version consistency if requested
        if(GV_FAIL_ON_MISMATCH)
          if(is_tagged AND NOT GV_DEFAULT_VERSION VERSION_EQUAL git_tag_version)
            message(SEND_ERROR "git_version_info(): Project version (${GV_DEFAULT_VERSION}) does not match Git tag (${git_tag_version})")
          elseif(is_development AND NOT GV_DEFAULT_VERSION VERSION_GREATER_EQUAL git_tag_version)
            message(SEND_ERROR "git_version_info(): Project version (${GV_DEFAULT_VERSION}) must be >= tagged ancestor (${git_tag_version})")
          endif()
        endif()
        
        # Build full version string according to SemVer 2.0.0
        if(is_tagged)
          # Tagged release: 1.2.3 or 1.2.3-dirty
          if(is_dirty)
            set(version_full "${git_tag_version}-dirty")
          else()
            set(version_full "${git_tag_version}")
          endif()
        else()
          # Development version: 1.2.3-dev.5+abc1234 or 1.2.3-dev.5+abc1234.dirty  
          set(version_full "${git_tag_version}-dev.${commit_count}")
          if(commit_hash)
            set(version_full "${version_full}+${commit_hash}")
            if(is_dirty)
              set(version_full "${version_full}.dirty")
            endif()
          endif()
        endif()
      endif()
    else()
      # No tags found - use default version with commit info
      if(commit_hash)
        if(is_dirty)
          set(version_full "${GV_DEFAULT_VERSION}+${commit_hash}.dirty")
        else()
          set(version_full "${GV_DEFAULT_VERSION}+${commit_hash}")
        endif()
      else()
        if(is_dirty)
          set(version_full "${GV_DEFAULT_VERSION}-dirty")
        else()
          set(version_full "${GV_DEFAULT_VERSION}")
        endif()
      endif()
    endif()
  endif()
  
  # Set output variables in parent scope
  if(GV_VERSION)
    set(${GV_VERSION} "${version_short}" PARENT_SCOPE)
  endif()
  if(GV_FULL_VERSION)
    set(${GV_FULL_VERSION} "${version_full}" PARENT_SCOPE)
  endif()
  if(GV_MAJOR)
    set(${GV_MAJOR} "${version_major}" PARENT_SCOPE)
  endif()
  if(GV_MINOR)
    set(${GV_MINOR} "${version_minor}" PARENT_SCOPE)
  endif()
  if(GV_PATCH)
    set(${GV_PATCH} "${version_patch}" PARENT_SCOPE)
  endif()
  if(GV_COMMIT_HASH)
    set(${GV_COMMIT_HASH} "${commit_hash}" PARENT_SCOPE)
  endif()
  if(GV_COMMIT_COUNT)
    set(${GV_COMMIT_COUNT} "${commit_count}" PARENT_SCOPE)
  endif()
  if(GV_IS_DIRTY)
    set(${GV_IS_DIRTY} "${is_dirty}" PARENT_SCOPE)
  endif()
  if(GV_IS_TAGGED)
    set(${GV_IS_TAGGED} "${is_tagged}" PARENT_SCOPE)
  endif()
  if(GV_IS_DEVELOPMENT)
    set(${GV_IS_DEVELOPMENT} "${is_development}" PARENT_SCOPE)
  endif()
  if(GV_TAG_NAME)
    set(${GV_TAG_NAME} "${tag_name}" PARENT_SCOPE)
  endif()
  if(GV_BRANCH_NAME)
    set(${GV_BRANCH_NAME} "${branch_name}" PARENT_SCOPE)
  endif()
endfunction()

function(gitversion_extract)
  git_version_info(${ARGN})
endfunction()
