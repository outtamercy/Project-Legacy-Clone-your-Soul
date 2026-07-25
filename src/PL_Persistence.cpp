#include "PL_Persistence.h"
#include <SKSE/SKSE.h>
#include <spdlog/spdlog.h>
#include <filesystem>
#include <fstream>

namespace fs = std::filesystem;

// Mirror of jcng's exported v1 api — must match their struct field-for-field.
// std::string by value across a dll boundary is spicy, but it's their contract
// and both ends are the same compiler, so we play by their rules.
using JCNG_Handle = std::uint32_t;

struct JCNG_API_V1 {
    int version;
    JCNG_Handle(*jmap_object)(RE::StaticFunctionTag*);
    void (*jmap_set_int)(RE::StaticFunctionTag*, JCNG_Handle, std::string, int32_t);
    int32_t(*jmap_get_int)(RE::StaticFunctionTag*, JCNG_Handle, std::string, int32_t);
    void (*jmap_set_str)(RE::StaticFunctionTag*, JCNG_Handle, std::string, std::string);
    std::string(*jmap_get_str)(RE::StaticFunctionTag*, JCNG_Handle, std::string, std::string);
    void (*jmap_set_obj)(RE::StaticFunctionTag*, JCNG_Handle, std::string, JCNG_Handle);
    JCNG_Handle(*jmap_get_obj)(RE::StaticFunctionTag*, JCNG_Handle, std::string, JCNG_Handle);
    void (*jmap_set_form)(RE::StaticFunctionTag*, JCNG_Handle, std::string, RE::TESForm*);
    RE::TESForm* (*jmap_get_form)(RE::StaticFunctionTag*, JCNG_Handle, std::string, RE::TESForm*);
    bool (*jmap_remove_key)(RE::StaticFunctionTag*, JCNG_Handle, std::string);
    void (*jvalue_write_to_file)(RE::StaticFunctionTag*, JCNG_Handle, std::string);
    JCNG_Handle(*jvalue_read_from_file)(RE::StaticFunctionTag*, std::string);
    JCNG_Handle(*jdb_root)(RE::StaticFunctionTag*);
};

static JCNG_API_V1* g_jcng = nullptr;

namespace PL {

    bool LinkJCNG() {
        // screw the messaging layer — jcng exports its api as a plain dll
        // function. GetModuleHandle (not LoadLibrary!) just checks if skse
        // already loaded them, then we grab the export and call it directly
        const char* dllNames[] = { "JContainers64.dll", "JContainersVR.dll", "JContainers.dll" };
        for (const char* name : dllNames) {
            HMODULE mod = GetModuleHandleA(name);
            if (!mod) continue;
            auto* fn = GetProcAddress(mod, "GetJContainersNGAPI");
            if (!fn) continue;
            g_jcng = reinterpret_cast<JCNG_API_V1 * (*)()>(fn)();
            if (g_jcng && g_jcng->version >= 1) {
                spdlog::info("PL: JCNG API v{} linked via {}", g_jcng->version, name);
                return true;
            }
        }
        spdlog::warn("PL: JCNG not found — slots won't persist without it");
        return false;
    }

    bool IsJCNGLinked() { return g_jcng != nullptr; }

    // ================= the registry =================
    // ONE store: a single jcng JMap, disk-backed via jcng's own file api —
    // ff's model exactly (their _ShrineOfHeroes.json beside the payloads).
    // no co-save, no sidecar json, no fallbacks. the dll owns the object:
    // read on boot + on every game load, mutate on bind/clear, commit via
    // jcng's native writeToFile.
    //
    // why the reload matters: jcng rebuilds its db on every game load, so a
    // handle read at boot is stale the moment the player loads a save.
    // plugin.cpp's TESLoadGameEvent sink calls ReloadRegistry() on every
    // load — that keeps the one store actually true.

    static JCNG_Handle g_registry = 0;
    // did the current handle come from a REAL file read? the load-event read
    // can fail when jcng's db for the incoming save isn't rebuilt yet — the
    // fallback empty jmap also gets a nonzero handle, so "handle=8" in the
    // log proved nothing. track truth, retry lazily on first access.
    static bool g_registryFromDisk = false;

    static std::string GetRegistryPath() {
        char exePath[MAX_PATH];
        GetModuleFileNameA(nullptr, exePath, MAX_PATH);
        fs::path dir = fs::path(exePath).parent_path() / "Data" / "SKSE" / "Plugins" / "ProjectLegacy";
        std::error_code ec;
        fs::create_directories(dir, ec);
        return (dir / "PL_Registry.json").string();
    }

    static bool TryReadRegistryFromDisk(const char* why) {
        auto path = GetRegistryPath();
        std::error_code ec;
        if (!fs::exists(path, ec)) {
            spdlog::info("PL: registry read ({}) — no file on disk", why);
            return false;
        }
        JCNG_Handle h = g_jcng->jvalue_read_from_file(nullptr, path);
        if (!h) {
            // jcng not ready / parse failed — log LOUDLY; this was the silent
            // cross-save killer (fell through to the empty jmap, every slot
            // read as vacant on the other character's save)
            spdlog::warn("PL: registry read ({}) FAILED — file exists but jcng returned 0; will retry on first access", why);
            return false;
        }
        g_registry = h;
        g_registryFromDisk = true;
        spdlog::info("PL: registry read ({}) ok, handle={}", why, g_registry);
        return true;
    }

    void ReloadRegistry() {
        if (!g_jcng) return;
        g_registryFromDisk = false;  // handles go stale across loads — never trust the old one
        if (TryReadRegistryFromDisk("load event")) {
            return;
        }
        if (!g_registry) {
            // no file yet (or unreadable) — start empty; first bind creates it
            g_registry = g_jcng->jmap_object(nullptr);
            spdlog::info("PL: no registry yet, started empty, handle={}", g_registry);
        }
    }

    static void CommitRegistry() {
        if (!g_jcng || !g_registry) return;
        g_jcng->jvalue_write_to_file(nullptr, g_registry, GetRegistryPath());
        g_registryFromDisk = true;  // we just wrote it — this handle is the truth
    }

    // never cache slot handles either — resolve fresh every call off the
    // one registry object. it's a map lookup, not a mortgage
    static JCNG_Handle GetSlotObj(int slot, bool create) {
        if (!g_jcng) return 0;
        // lazy self-heal: if the load-event read failed (jcng db not rebuilt
        // yet at event time), the first real access — the load sweep, an
        // OnCellLoad prompt refresh — retries now that jcng has settled
        if (!g_registryFromDisk) {
            TryReadRegistryFromDisk("lazy access");
        }
        if (!g_registry) return 0;
        std::string key = "slot_" + std::to_string(slot);
        JCNG_Handle h = g_jcng->jmap_get_obj(nullptr, g_registry, key, 0);
        if (!h && create) {
            h = g_jcng->jmap_object(nullptr);
            g_jcng->jmap_set_obj(nullptr, g_registry, key, h);
        }
        return h;
    }

    void SetSlotBound(int slot, const std::string& charName, int sex, RE::TESForm* raceForm, const std::string& raceStr) {
        JCNG_Handle h = GetSlotObj(slot, true);
        if (!h) {
            spdlog::error("PL: SetSlotBound slot {} — no registry", slot);
            return;
        }
        g_jcng->jmap_set_int(nullptr, h, "bound", 1);
        g_jcng->jmap_set_str(nullptr, h, "name", charName);
        g_jcng->jmap_set_int(nullptr, h, "sex", sex);
        // forms can't ride a json file meaningfully (load-order dependent),
        // so the registry stores race_str only; GetSlotRaceForm re-resolves
        // it through the data handler on every read. (void)raceForm — kept
        // in the signature so callers don't change.
        (void)raceForm;
        g_jcng->jmap_set_str(nullptr, h, "race_str", raceStr);
        CommitRegistry();
    }

    bool IsSlotBound(int slot) {
        JCNG_Handle h = GetSlotObj(slot, false);
        return h && g_jcng->jmap_get_int(nullptr, h, "bound", 0) == 1;
    }

    std::string GetSlotCharName(int slot) {
        JCNG_Handle h = GetSlotObj(slot, false);
        return h ? g_jcng->jmap_get_str(nullptr, h, "name", "") : "";
    }

    int GetSlotSex(int slot) {
        JCNG_Handle h = GetSlotObj(slot, false);
        return h ? g_jcng->jmap_get_int(nullptr, h, "sex", 0) : 0;
    }

    RE::TESForm* GetSlotRaceForm(int slot) {
        JCNG_Handle h = GetSlotObj(slot, false);
        if (!h) return nullptr;
        std::string raceStr = g_jcng->jmap_get_str(nullptr, h, "race_str", "");
        auto pipe = raceStr.find("|0x");
        if (pipe == std::string::npos) return nullptr;
        std::string modName = raceStr.substr(0, pipe);
        try {
            uint32_t localID = std::stoul(raceStr.substr(pipe + 3), nullptr, 16);
            auto* dh = RE::TESDataHandler::GetSingleton();
            return dh ? dh->LookupForm(localID, modName) : nullptr;
        }
        catch (...) {
            return nullptr;
        }
    }

    std::string GetSlotRaceString(int slot) {
        JCNG_Handle h = GetSlotObj(slot, false);
        return h ? g_jcng->jmap_get_str(nullptr, h, "race_str", "") : "";
    }

    void ClearSlot(int slot) {
        if (!g_jcng || !g_registry) return;
        g_jcng->jmap_remove_key(nullptr, g_registry, "slot_" + std::to_string(slot));
        CommitRegistry();
    }
}
