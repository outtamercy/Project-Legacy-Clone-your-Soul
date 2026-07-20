//Papyrus.h
#pragma once
#include <SKSE/SKSE.h>

namespace ProjectLegacy::Papyrus {
    void BreakPlayerAnimation(RE::StaticFunctionTag*, RE::Actor* player);
    bool RegisterFunctions(RE::BSScript::IVirtualMachine* vm);
    bool ApplyPlayerPreset(RE::Actor* self, int32_t slot);
    bool ApplyPlayerGear(RE::Actor* self, int32_t slot);
    RE::BSFixedString GetSlotDiskName(RE::StaticFunctionTag*, int32_t slot);
    RE::TESForm* GetSlotRaceForm(RE::StaticFunctionTag*, int32_t slot);
    int32_t GetSlotVesselSex(RE::StaticFunctionTag*, int32_t slot);
}