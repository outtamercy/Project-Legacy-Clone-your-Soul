#include "PL_Persistence.h"
#include "FormSerializer.hpp"
#include <fstream>
#include <filesystem>
namespace fs = std::filesystem;
using json = nlohmann::json;

namespace PL {
    fs::path GetRegistryPath() { return fs::path("Data/SKSE/Plugins/ProjectLegacy/slot_registry.json"); }

    Handle GetSlotRegistry() {
        auto root = ObjectManager::Get().GetJDBRoot();
        auto ptr = ObjectManager::Get().GetObject(root);
        if (!ptr) return 0;
        if (!ptr->contains("PL_Slots")) {
            Handle h = ObjectManager::Get().CreateObject();
            (*ptr)["PL_Slots"] = ObjectManager::MakeRef(h);
            return h;
        }
        auto& ref = (*ptr)["PL_Slots"];
        Handle h;
        if (ObjectManager::IsRef(ref, &h)) return h;
        h = ObjectManager::Get().CreateObject();
        ref = ObjectManager::MakeRef(h);
        return h;
    }

    void SetSlotBound(int slot, const std::string& diskName, int sex, RE::TESForm* raceForm) {
        auto reg = GetSlotRegistry();
        if (!reg) return;
        auto ptr = ObjectManager::Get().GetObject(reg);
        if (!ptr) return;
        (*ptr)["slot_" + std::to_string(slot)] = json::object({
            {"bound", 1}, {"disk_name", diskName}, {"sex", sex},
            {"race", FormSerializer::EncodeForm(raceForm)}
        });
    }

    bool IsSlotBound(int slot) {
        auto reg = GetSlotRegistry();
        if (!reg) return false;
        auto ptr = ObjectManager::Get().GetObject(reg);
        if (!ptr) return false;
        auto key = "slot_" + std::to_string(slot);
        if (!ptr->contains(key)) return false;
        auto& slotObj = (*ptr)[key];
        return slotObj.is_object() && slotObj.contains("bound") && slotObj["bound"].get<int>() == 1;
    }

    std::string GetSlotDiskName(int slot) {
        auto reg = GetSlotRegistry(); auto ptr = ObjectManager::Get().GetObject(reg);
        if (!ptr || !ptr->contains("slot_" + std::to_string(slot))) return "";
        auto& s = (*ptr)["slot_" + std::to_string(slot)];
        return (s.is_object() && s.contains("disk_name")) ? s["disk_name"].get<std::string>() : "";
    }

    RE::TESForm* GetSlotRaceForm(int slot) {
        auto reg = GetSlotRegistry(); auto ptr = ObjectManager::Get().GetObject(reg);
        if (!ptr || !ptr->contains("slot_" + std::to_string(slot))) return nullptr;
        auto& s = (*ptr)["slot_" + std::to_string(slot)];
        if (!s.is_object() || !s.contains("race")) return nullptr;
        std::string r = s["race"].get<std::string>();
        return FormSerializer::IsFormString(r) ? FormSerializer::DecodeForm(r) : nullptr;
    }

    int GetSlotSex(int slot) {
        auto reg = GetSlotRegistry(); auto ptr = ObjectManager::Get().GetObject(reg);
        if (!ptr || !ptr->contains("slot_" + std::to_string(slot))) return 0;
        auto& s = (*ptr)["slot_" + std::to_string(slot)];
        return (s.is_object() && s.contains("sex")) ? s["sex"].get<int>() : 0;
    }

    void ClearSlot(int slot) {
        auto reg = GetSlotRegistry(); auto ptr = ObjectManager::Get().GetObject(reg);
        if (ptr) ptr->erase("slot_" + std::to_string(slot));
    }

    void ExportSlotRegistry() {
        auto reg = GetSlotRegistry(); auto ptr = ObjectManager::Get().GetObject(reg);
        if (!ptr) return;
        auto p = GetRegistryPath(); fs::create_directories(p.parent_path());
        std::ofstream f(p); f << ptr->dump(2);
    }

    void ImportSlotRegistry() {
        auto p = GetRegistryPath(); if (!fs::exists(p)) return;
        std::ifstream f(p); if (!f.is_open()) return;
        try { json j; f >> j; auto reg = GetSlotRegistry(); auto ptr = ObjectManager::Get().GetObject(reg); if (ptr) *ptr = j; }
        catch (...) {}
    }
}