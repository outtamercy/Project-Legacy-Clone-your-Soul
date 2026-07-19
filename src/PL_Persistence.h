#pragma once
#include "ObjectManager.hpp"
#include <string>

namespace PL {
    using Handle = ObjectManager::Handle;
    Handle GetSlotRegistry();
    void SetSlotBound(int slot, const std::string& diskName, int sex, RE::TESForm* raceForm);
    bool IsSlotBound(int slot);
    std::string GetSlotDiskName(int slot);
    RE::TESForm* GetSlotRaceForm(int slot);
    int GetSlotSex(int slot);
    void ClearSlot(int slot);
    void ExportSlotRegistry();
    void ImportSlotRegistry();
}