#pragma once
#include <string>
#include <cstdint>
#include <RE/Skyrim.h>

namespace PL {
    // jcng link — the registry lives in THEIR dll, we just borrow it through the api
    bool LinkJCNG();
    bool IsJCNGLinked();

    // slot registry — ONE jcng JMap, disk-backed via jcng's own file api
    // (PL_Registry.json beside the payloads, ff's _ShrineOfHeroes.json model).
    // the dll owns the object: ReloadRegistry reads it from disk on boot and
    // on every game load (jcng rebuilds its db on load — handles go stale),
    // SetSlotBound/ClearSlot mutate it and commit via jcng's writeToFile.
    void ReloadRegistry();
    void SetSlotBound(int slot, const std::string& charName, int sex, RE::TESForm* raceForm, const std::string& raceStr);
    bool IsSlotBound(int slot);
    std::string GetSlotCharName(int slot);
    int GetSlotSex(int slot);
    RE::TESForm* GetSlotRaceForm(int slot);
    std::string GetSlotRaceString(int slot);
    void ClearSlot(int slot);
}
