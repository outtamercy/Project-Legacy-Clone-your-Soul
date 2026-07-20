#include "PL_Persistence.h"
#include <SKSE/SKSE.h>
#include <spdlog/spdlog.h>

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
                spdlog::info("PL: JCNG API v{} linked via {} — registry rides their co-save now", g_jcng->version, name);
                return true;
            }
        }
        spdlog::warn("PL: JCNG not found — slots won't persist without it");
        return false;
    }

    bool IsJCNGLinked() { return g_jcng != nullptr; }

    // never cache handles — jcng rebuilds the db on every load. same values come
    // back for co-saved stuff, but a fresh game hands out fresh ones, so resolve
    // fresh every call. it's a map lookup, not a mortgage
    static JCNG_Handle GetSlotsMap() {
        if (!g_jcng) return 0;
        JCNG_Handle root = g_jcng->jdb_root(nullptr);
        if (!root) return 0;
        JCNG_Handle h = g_jcng->jmap_get_obj(nullptr, root, "PL_Slots", 0);
        if (!h) {
            h = g_jcng->jmap_object(nullptr);
            g_jcng->jmap_set_obj(nullptr, root, "PL_Slots", h);
        }
        return h;
    }

    static JCNG_Handle GetSlotObj(int slot, bool create) {
        JCNG_Handle reg = GetSlotsMap();
        if (!reg) return 0;
        std::string key = "slot_" + std::to_string(slot);
        JCNG_Handle h = g_jcng->jmap_get_obj(nullptr, reg, key, 0);
        if (!h && create) {
            h = g_jcng->jmap_object(nullptr);
            g_jcng->jmap_set_obj(nullptr, reg, key, h);
        }
        return h;
    }

    void SetSlotBound(int slot, const std::string& charName, int sex, RE::TESForm* raceForm, const std::string& raceStr) {
        JCNG_Handle h = GetSlotObj(slot, true);
        if (!h) return;
        g_jcng->jmap_set_int(nullptr, h, "bound", 1);
        g_jcng->jmap_set_str(nullptr, h, "name", charName);
        g_jcng->jmap_set_int(nullptr, h, "sex", sex);
        // real form ref rides jcng's dirty-sweep — mod uninstalled = null, not crash.
        // race_str is the "ModName.esp|0xID" fallback for manual re-resolution
        if (raceForm) g_jcng->jmap_set_form(nullptr, h, "race", raceForm);
        g_jcng->jmap_set_str(nullptr, h, "race_str", raceStr);
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
        return h ? g_jcng->jmap_get_form(nullptr, h, "race", nullptr) : nullptr;
    }

    std::string GetSlotRaceString(int slot) {
        JCNG_Handle h = GetSlotObj(slot, false);
        return h ? g_jcng->jmap_get_str(nullptr, h, "race_str", "") : "";
    }

    void ClearSlot(int slot) {
        JCNG_Handle reg = GetSlotsMap();
        if (reg) g_jcng->jmap_remove_key(nullptr, reg, "slot_" + std::to_string(slot));
    }
}