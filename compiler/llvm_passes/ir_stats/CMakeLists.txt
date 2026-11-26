cmake_minimum_required(VERSION 3.20)

project(IRStatsPass LANGUAGES CXX)

# LLVM's official Windows package was linked against static zstd, while some
# machines only expose the zstd import library. Give LLVMConfig the target name
# it expects and forward it to the available zstd target.
if(WIN32)
    list(APPEND CMAKE_MODULE_PATH "${LLVM_DIR}")
    find_package(zstd REQUIRED)
    if(NOT TARGET zstd::libzstd_static AND TARGET zstd::libzstd_shared)
        add_library(zstd::libzstd_static INTERFACE IMPORTED)
        set_property(TARGET zstd::libzstd_static PROPERTY
                     INTERFACE_LINK_LIBRARIES zstd::libzstd_shared)
    endif()
endif()

find_package(LLVM REQUIRED CONFIG)

list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(AddLLVM)

# The official Windows LLVM archive is built from static libraries and reports
# LLVM_ENABLE_PLUGINS=OFF. opt.exe still supports -load-pass-plugin, so build
# the plugin as an explicit DLL and link the required LLVM components into it.
if(WIN32 AND NOT LLVM_ENABLE_PLUGINS)
    add_library(IRStatsPass MODULE IRStatsPass.cpp IRStatsPass.def)
    llvm_map_components_to_libnames(LLVM_LIBRARIES Core Passes Support)
    target_link_libraries(IRStatsPass PRIVATE ${LLVM_LIBRARIES})
else()
    add_llvm_pass_plugin(IRStatsPass IRStatsPass.cpp)
endif()

target_compile_features(IRStatsPass PRIVATE cxx_std_17)
target_include_directories(IRStatsPass SYSTEM PRIVATE ${LLVM_INCLUDE_DIRS})
target_compile_definitions(IRStatsPass PRIVATE ${LLVM_DEFINITIONS})
