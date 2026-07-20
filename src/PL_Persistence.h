#pragma once
#include <string>
#include <cstdint>
#include <RE/Skyrim.h>

namespace PL {
    // jcng link — the registry lives in THEIR dll, we just borrow it through the api
    bool LinkJCNG();
    bool IsJCNGLinked();

    // slot registry — PL_Slots map hanging off jcng's jdb root.
    // jcng co-saves the whole jdb, so persistence is their problem now. nice.
    void SetSlotBound(int slot, const std::string& charName, int sex, RE::TESForm* raceForm, const std::string& raceStr);
    bool IsSlotBound(int slot);
    std::string GetSlotCharName(int slot);
    int GetSlotSex(int slot);
    RE::TESForm* GetSlotRaceForm(int slot);
    std::string GetSlotRaceString(int slot);
    void ClearSlot(int slot);
}