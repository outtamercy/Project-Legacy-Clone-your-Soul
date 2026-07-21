#include "log.h"
#include "Papyrus.h"
#include <SKSE/SKSE.h>

SKSEPluginLoad(const SKSE::LoadInterface* skse)
{
    try {
        SKSE::Init(skse);
        SetupLog();

        auto papyrus = SKSE::GetPapyrusInterface();
        if (!papyrus) {
            spdlog::error("PL: no papyrus interface, bailin'");
            return false;
        }

        bool ok = papyrus->Register(ProjectLegacy::Papyrus::RegisterFunctions);
        if (!ok) {
            spdlog::error("PL: papyrus registration failed");
            return false;
        }

        spdlog::info("Project Legacy: loaded and ready");
        return true;
    }
    catch (const std::exception& e) {
        // if logger isn't up yet, scream into the debug output
        SKSE::log::error("PL: crashed during load: {}", e.what());
        return false;
    }
}