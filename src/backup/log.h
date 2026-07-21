#pragma once
#include <spdlog/spdlog.h>
#include <spdlog/sinks/basic_file_sink.h>
#include <SKSE/Logger.h>

inline void SetupLog() {
    auto path = SKSE::log::log_directory();
    if (!path) return;

    *path /= "ProjectLegacy.log";

    // don't fight other plugins for the name "global"
    auto logger = spdlog::basic_logger_mt("ProjectLegacy", path->string(), true);
    spdlog::set_default_logger(logger);
    spdlog::set_level(spdlog::level::info);
    spdlog::flush_on(spdlog::level::info);
}