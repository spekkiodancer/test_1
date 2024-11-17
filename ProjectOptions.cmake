include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(test_1_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(test_1_setup_options)
  option(test_1_ENABLE_HARDENING "Enable hardening" ON)
  option(test_1_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    test_1_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    test_1_ENABLE_HARDENING
    OFF)

  test_1_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR test_1_PACKAGING_MAINTAINER_MODE)
    option(test_1_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(test_1_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(test_1_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(test_1_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(test_1_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(test_1_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(test_1_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(test_1_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(test_1_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(test_1_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(test_1_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(test_1_ENABLE_PCH "Enable precompiled headers" OFF)
    option(test_1_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(test_1_ENABLE_IPO "Enable IPO/LTO" ON)
    option(test_1_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(test_1_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(test_1_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(test_1_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(test_1_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(test_1_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(test_1_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(test_1_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(test_1_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(test_1_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(test_1_ENABLE_PCH "Enable precompiled headers" OFF)
    option(test_1_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      test_1_ENABLE_IPO
      test_1_WARNINGS_AS_ERRORS
      test_1_ENABLE_USER_LINKER
      test_1_ENABLE_SANITIZER_ADDRESS
      test_1_ENABLE_SANITIZER_LEAK
      test_1_ENABLE_SANITIZER_UNDEFINED
      test_1_ENABLE_SANITIZER_THREAD
      test_1_ENABLE_SANITIZER_MEMORY
      test_1_ENABLE_UNITY_BUILD
      test_1_ENABLE_CLANG_TIDY
      test_1_ENABLE_CPPCHECK
      test_1_ENABLE_COVERAGE
      test_1_ENABLE_PCH
      test_1_ENABLE_CACHE)
  endif()

  test_1_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (test_1_ENABLE_SANITIZER_ADDRESS OR test_1_ENABLE_SANITIZER_THREAD OR test_1_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(test_1_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(test_1_global_options)
  if(test_1_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    test_1_enable_ipo()
  endif()

  test_1_supports_sanitizers()

  if(test_1_ENABLE_HARDENING AND test_1_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR test_1_ENABLE_SANITIZER_UNDEFINED
       OR test_1_ENABLE_SANITIZER_ADDRESS
       OR test_1_ENABLE_SANITIZER_THREAD
       OR test_1_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${test_1_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${test_1_ENABLE_SANITIZER_UNDEFINED}")
    test_1_enable_hardening(test_1_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(test_1_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(test_1_warnings INTERFACE)
  add_library(test_1_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  test_1_set_project_warnings(
    test_1_warnings
    ${test_1_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(test_1_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    test_1_configure_linker(test_1_options)
  endif()

  include(cmake/Sanitizers.cmake)
  test_1_enable_sanitizers(
    test_1_options
    ${test_1_ENABLE_SANITIZER_ADDRESS}
    ${test_1_ENABLE_SANITIZER_LEAK}
    ${test_1_ENABLE_SANITIZER_UNDEFINED}
    ${test_1_ENABLE_SANITIZER_THREAD}
    ${test_1_ENABLE_SANITIZER_MEMORY})

  set_target_properties(test_1_options PROPERTIES UNITY_BUILD ${test_1_ENABLE_UNITY_BUILD})

  if(test_1_ENABLE_PCH)
    target_precompile_headers(
      test_1_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(test_1_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    test_1_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(test_1_ENABLE_CLANG_TIDY)
    test_1_enable_clang_tidy(test_1_options ${test_1_WARNINGS_AS_ERRORS})
  endif()

  if(test_1_ENABLE_CPPCHECK)
    test_1_enable_cppcheck(${test_1_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(test_1_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    test_1_enable_coverage(test_1_options)
  endif()

  if(test_1_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(test_1_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(test_1_ENABLE_HARDENING AND NOT test_1_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR test_1_ENABLE_SANITIZER_UNDEFINED
       OR test_1_ENABLE_SANITIZER_ADDRESS
       OR test_1_ENABLE_SANITIZER_THREAD
       OR test_1_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    test_1_enable_hardening(test_1_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
