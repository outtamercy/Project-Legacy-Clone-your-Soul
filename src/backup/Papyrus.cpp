#include "Papyrus.h"
#include <RE/I/InventoryEntryData.h>

#include <RE/A/Actor.h>
#include <RE/T/TESNPC.h>
#include <RE/B/BGSVoiceType.h>
#include <RE/T/TESRace.h>
#include <RE/P/PlayerCharacter.h>
#include <RE/T/TESObjectMISC.h>
#include <RE/I/ItemRemoveReason.h>
#include <RE/T/TESObjectREFR.h>

#include <SKSE/SKSE.h>
#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>
#include <filesystem>
#include <fstream>
#include <ctime>
#include <thread>
#include <chrono>
#include <vector>
#include <windows.h>
#include <sstream>
#include <iomanip>
#include <cmath>

namespace fs = std::filesystem;
using json = nlohmann::json;

namespace {
    fs::path GetGamePath() {
        wchar_t path[MAX_PATH];
        GetModuleFileNameW(nullptr, path, MAX_PATH);
        return fs::path(path).parent_path();
    }

    fs::path GetDLLDir() {
        return GetGamePath() / "Data" / "SKSE" / "Plugins";
    }

    fs::path GetLegacyDir() {
        auto dir = GetDLLDir() / "ProjectLegacy";
        std::error_code ec;
        fs::create_directories(dir, ec);
        return dir;
    }

    fs::path GetSlotFile(int slot) {
        return GetLegacyDir() / ("slot_" + std::to_string(slot) + ".json");
    }

    fs::path GetCharGenPath(const std::string& name) {
        return GetGamePath() / "Data" / "SKSE" / "Plugins" / "CharGen" / "Exported" / (name + ".jslot");
    }

    fs::path GetCharGenTexturePath(const std::string& name) {
        return GetGamePath() / "Data" / "Textures" / "CharGen" / "Exported" / (name + ".dds");
    }

    std::string GetModFormID(RE::TESForm* form) {
        if (!form) return "0";

        auto file = form->GetFile(0);
        if (!file) {
            std::stringstream ss;
            ss << "0x" << std::hex << form->GetFormID();
            return ss.str();
        }

        std::string modName(file->GetFilename());
        uint32_t formID = form->GetFormID();
        uint32_t localID = formID & 0xFFFFFF;

        if ((formID >> 24) == 0xFE) {
            localID = formID & 0xFFF;
        }

        std::stringstream ss;
        ss << modName << "|0x" << std::hex << localID;
        return ss.str();
    }
}

namespace ProjectLegacy::Papyrus {

    void BreakPlayerAnimation(RE::StaticFunctionTag*, RE::Actor* player) {
        if (!player) return;

        auto task = SKSE::GetTaskInterface();
        if (!task) return;

        task->AddTask([player]() {
            // 1. Break the vanilla ascend loop
            player->NotifyAnimationGraph("IdleStop_loose");
            // 2. Sledgehammer pelvis to collision layer
            player->NotifyAnimationGraph("BleedOutStart");
            });
    }

    void ClearPlayerAnimation(RE::StaticFunctionTag*, RE::Actor* player) {
        if (!player) return;

        auto task = SKSE::GetTaskInterface();
        if (!task) return;

        task->AddTask([player]() {
            player->NotifyAnimationGraph("BleedOutStop");
            });
    }

    int32_t ProcessSellChest(RE::StaticFunctionTag*, RE::TESObjectREFR* junkChest, RE::TESObjectREFR* goldChest, float sellPct) {
        if (!junkChest || !goldChest) {
            return 0;
        }

        int32_t totalGold = 0;
        auto inventory = junkChest->GetInventory();

        std::vector<std::pair < RE::TESBoundObject*, int32_t >> itemsToRemove;

        for (auto& [item, data] : inventory) {
            if (!item || data.first <= 0) {
                continue;
            }

            int32_t count = data.first;
            float singleValue = static_cast<float>(item->GetGoldValue()) * sellPct;
            int32_t itemTotal = static_cast<int32_t>(std::floor(singleValue * count));

            if (itemTotal > 0) {
                totalGold += itemTotal;
                itemsToRemove.push_back({ item, count });
            }
        }

        for (auto& [item, count] : itemsToRemove) {
            junkChest->RemoveItem(item, count, RE::ITEM_REMOVE_REASON::kRemove, nullptr, nullptr);
        }

        if (totalGold > 0) {
            auto goldForm = RE::TESForm::LookupByID < RE::TESObjectMISC >(0x0000000F);
            if (goldForm) {
                goldChest->AddObjectToContainer(goldForm, nullptr, totalGold, nullptr);
            }
        }

        return totalGold;
    }

    bool IsSlotBound(RE::StaticFunctionTag*, int32_t slot) {
        return fs::exists(GetSlotFile(slot));
    }

    RE::BSFixedString GetLegacyDirString(RE::StaticFunctionTag*) {
        std::string pathStr = GetLegacyDir().string();
        return RE::BSFixedString(pathStr.c_str());
    }

    RE::BSFixedString GetGamePathString(RE::StaticFunctionTag*) {
        std::string pathStr = GetGamePath().string();
        return RE::BSFixedString(pathStr.c_str());
    }

    int32_t ExportPlayerPreset(RE::StaticFunctionTag*, int32_t slot, RE::BSFixedString slotName) {
        std::string name = slotName.c_str();

        auto legacyDir = GetLegacyDir();
        std::error_code ec;
        if (!fs::exists(legacyDir)) {
            fs::create_directories(legacyDir, ec);
            if (ec) {
                spdlog::error("PL: Dir create failed: {}", ec.message());
                return 5;
            }
        }

        spdlog::info("PL: DLL dir = {}", GetDLLDir().string());
        spdlog::info("PL: Legacy dir = {}", legacyDir.string());
        spdlog::info("PL: Slot file = {}", GetSlotFile(slot).string());

        auto srcJslot = GetCharGenPath(name);
        auto srcDds = GetCharGenTexturePath(name);

        spdlog::info("PL: CharGen jslot = {}", srcJslot.string());
        spdlog::info("PL: CharGen dds = {}", srcDds.string());

        int attempts = 60;
        while ((!fs::exists(srcJslot) || !fs::exists(srcDds)) && attempts > 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
            attempts--;
        }

        if (!fs::exists(srcJslot)) {
            spdlog::error("PL: jslot missing: {}", srcJslot.string());
            return 1;
        }
        if (!fs::exists(srcDds)) {
            spdlog::error("PL: dds missing: {}", srcDds.string());
            return 2;
        }

        auto dstJslot = legacyDir / (name + ".jslot");
        auto dstDds = legacyDir / (name + ".dds");

        fs::copy_file(srcJslot, dstJslot, fs::copy_options::overwrite_existing, ec);
        if (ec) {
            spdlog::error("PL: jslot copy failed: {}", ec.message());
            return 3;
        }
        fs::remove(srcJslot, ec);

        fs::copy_file(srcDds, dstDds, fs::copy_options::overwrite_existing, ec);
        if (ec) {
            spdlog::error("PL: dds copy failed: {}", ec.message());
            return 4;
        }
        fs::remove(srcDds, ec);

        auto player = RE::PlayerCharacter::GetSingleton();
        if (!player) return 8;
        auto playerBase = player->GetActorBase();
        auto trueRace = player->GetRace();
        auto trueVoice = playerBase ? playerBase->voiceType : nullptr;
        bool isFemale = playerBase ? playerBase->GetSex() == RE::SEX::kFemale : false;
        const char* playerName = playerBase ? playerBase->GetName() : "";

        json data;
        data["slot"] = slot;
        data["slot_name"] = name;
        data["player_name"] = playerName ? playerName : "";
        data["bound"] = true;
        data["timestamp"] = std::time(nullptr);
        data["gender"] = isFemale ? "female" : "male";
        data["race_form_id"] = GetModFormID(trueRace);
        data["voice_form_id"] = GetModFormID(trueVoice);
        data["perks"] = json::array();
        data["spells"] = json::array();
        data["shouts"] = json::array();
        data["inventory"] = json::array();
        data["equipment"] = json::object();
        data["stats"] = json::object();

        auto slotPath = GetSlotFile(slot);
        spdlog::info("PL: Opening JSON: {}", slotPath.string());

        std::ofstream f(slotPath.wstring(), std::ios::out | std::ios::trunc);
        if (!f.is_open()) {
            spdlog::error("PL: JSON open failed: {}", slotPath.string());
            return 6;
        }

        f << data.dump(4);
        f.flush();
        bool failed = f.fail();
        f.close();

        if (failed) {
            spdlog::error("PL: JSON write failed");
            return 7;
        }

        spdlog::info("PL: JSON written successfully");
        return 0;
    }

    bool ClearSlot(RE::StaticFunctionTag*, int32_t slot) {
        auto legacyDir = GetLegacyDir();
        auto slotFile = GetSlotFile(slot);
        std::string name = "PL_Slot" + std::to_string(slot);

        if (fs::exists(slotFile)) {
            std::ifstream f(slotFile);
            if (f.is_open()) {
                try {
                    json data = json::parse(f);
                    if (data.contains("slot_name") && data["slot_name"].is_string()) {
                        name = data["slot_name"].get<std::string>();
                    }
                }
                catch (...) {}
                f.close();
            }
        }

        std::error_code ec;
        fs::remove(slotFile, ec);
        fs::remove(legacyDir / (name + ".jslot"), ec);
        fs::remove(legacyDir / (name + ".dds"), ec);

        return true;
    }

    bool StageSlotForLoad(RE::StaticFunctionTag*, int32_t slot, RE::BSFixedString slotName) {
        std::string name = slotName.c_str();
        auto legacyDir = GetLegacyDir();
        auto srcJslot = legacyDir / (name + ".jslot");
        auto srcDds = legacyDir / (name + ".dds");
        auto dstJslot = GetCharGenPath(name);
        auto dstDds = GetCharGenTexturePath(name);

        std::error_code ec;
        fs::create_directories(dstJslot.parent_path(), ec);
        fs::create_directories(dstDds.parent_path(), ec);

        if (fs::exists(srcJslot)) {
            fs::copy_file(srcJslot, dstJslot, fs::copy_options::overwrite_existing, ec);
        }
        if (fs::exists(srcDds)) {
            fs::copy_file(srcDds, dstDds, fs::copy_options::overwrite_existing, ec);
        }
        return true;
    }

    bool UnstageSlotAfterLoad(RE::StaticFunctionTag*, int32_t slot, RE::BSFixedString slotName) {
        std::string name = slotName.c_str();
        auto dstJslot = GetCharGenPath(name);
        auto dstDds = GetCharGenTexturePath(name);
        std::error_code ec;
        fs::remove(dstJslot, ec);
        fs::remove(dstDds, ec);
        return true;
    }

    bool ClearDefaultOutfit(RE::StaticFunctionTag*, RE::Actor* actor) {
        if (!actor) return false;
        auto actorBase = actor->GetActorBase();
        if (actorBase) {
            actorBase->defaultOutfit = nullptr;
            return true;
        }
        return false;
    }

    bool SetActorBaseSex(RE::StaticFunctionTag*, RE::Actor* actor, int32_t sex) {
        if (!actor) return false;
        auto npc = actor->GetActorBase();
        if (!npc) return false;

        if (sex == 1) {
            npc->actorData.actorBaseFlags.set(RE::ACTOR_BASE_DATA::Flag::kFemale);
        }
        else {
            npc->actorData.actorBaseFlags.reset(RE::ACTOR_BASE_DATA::Flag::kFemale);
        }
        return true;
    }

    bool IsSKSEPluginLoaded(RE::StaticFunctionTag*) {
        return true;
    }

    bool RegisterFunctions(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("IsSlotBound", "PL_StationScript", IsSlotBound, true);
        vm->RegisterFunction("GetLegacyDirString", "PL_StationScript", GetLegacyDirString, true);
        vm->RegisterFunction("GetGamePathString", "PL_StationScript", GetGamePathString, true);
        vm->RegisterFunction("ExportPlayerPreset", "PL_StationScript", ExportPlayerPreset, true);
        vm->RegisterFunction("ClearSlot", "PL_StationScript", ClearSlot, true);
        vm->RegisterFunction("StageSlotForLoad", "PL_VesselActor", StageSlotForLoad, true);
        vm->RegisterFunction("UnstageSlotAfterLoad", "PL_VesselActor", UnstageSlotAfterLoad, true);
        vm->RegisterFunction("ClearDefaultOutfit", "PL_VesselActor", ClearDefaultOutfit, true);
        vm->RegisterFunction("SetActorBaseSex", "PL_VesselActor", SetActorBaseSex, true);
        vm->RegisterFunction("IsSKSEPluginLoaded", "PL_ManagerQuest", IsSKSEPluginLoaded, true);
        vm->RegisterFunction("ProcessSellChest", "BennyShelterSellChestScript", ProcessSellChest, true);
        vm->RegisterFunction("BreakPlayerAnimation", "PL_StationScript", BreakPlayerAnimation, true);
        vm->RegisterFunction("ClearPlayerAnimation", "PL_StationScript", ClearPlayerAnimation, true);

        spdlog::info("Project Legacy: Papyrus functions registered.");
        return true;
    }
}