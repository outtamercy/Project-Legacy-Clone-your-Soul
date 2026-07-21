#pragma once
#include <SKSE/SKSE.h>

namespace ProjectLegacy::Papyrus {
    void BreakPlayerAnimation(RE::StaticFunctionTag*, RE::Actor* player);
    bool RegisterFunctions(RE::BSScript::IVirtualMachine* vm);
}