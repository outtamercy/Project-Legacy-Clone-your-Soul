cmake_minimum_required(VERSION 3.21)
project(ProjectLegacy VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(CommonLibSSE CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(directxtk CONFIG REQUIRED)

set(SOURCES
    src/plugin.cpp
    src/Papyrus.cpp
    src/PL_Persistence.cpp
)

# 1. Target is created FIRST
add_commonlibsse_plugin(${PROJECT_NAME} SOURCES ${SOURCES})

target_precompile_headers(${PROJECT_NAME} PRIVATE src/PCH.h)

# 2. Target properties are assigned SECOND (Consolidated here)
target_include_directories(${PROJECT_NAME} PRIVATE 
    include
    src
    "${CMAKE_CURRENT_SOURCE_DIR}/../JContainers NG/src"
)

target_link_libraries(${PROJECT_NAME} PRIVATE 
    nlohmann_json::nlohmann_json
)

set(OUTPUT_FOLDER "H:/Mayhem's Madness AE/mods/Project Legacy")
set(DLL_FOLDER "${OUTPUT_FOLDER}/SKSE/Plugins")

add_custom_command(
    TARGET ${PROJECT_NAME}
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${DLL_FOLDER}
    COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:${PROJECT_NAME}> ${DLL_FOLDER}/
    VERBATIM
)