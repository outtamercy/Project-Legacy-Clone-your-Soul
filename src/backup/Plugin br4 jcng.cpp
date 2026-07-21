//Plugin.cpp

#include "Papyrus.h"
#include <RE/A/Actor.h>
#include <RE/A/ActorEquipManager.h>
#include <RE/B/BGSBipedObjectForm.h>
#include <RE/B/BGSVoiceType.h>
#include <RE/I/ItemRemoveReason.h>
#include <RE/P/PlayerCharacter.h>
#include <RE/T/TESNPC.h>
#include <RE/T/TESObjectARMO.h>
#include <RE/T/TESObjectMISC.h>
#include <RE/T/TESObjectREFR.h>
#include <RE/T/TESObjectWEAP.h>
#include <RE/T/TESRace.h>

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
#include <mutex>
#include <atomic>
#include <algorithm>
#include <regex>

#ifdef min
#undef min
#endif
#ifdef max
#undef max
#endif

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

    std::string SanitizeFileName(const std::string& name) {
        std::string clean = name;
        std::replace(clean.begin(), clean.end(), ' ', '_');
        clean = std::regex_replace(clean, std::regex("[^a-zA-Z0-9_]"), "");
        if (clean.empty()) clean = "Unknown";
        return clean;
    }
}

namespace ProjectLegacy::Papyrus {

    void BreakPlayerAnimation(RE::StaticFunctionTag*, RE::Actor* player) {
        if (!player) return;
        auto task = SKSE::GetTaskInterface();
        if (!task) return;
        task->AddTask([player]() {
            player->NotifyAnimationGraph("IdleStop_loose");
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

    void RemoveRaceSpells(RE::StaticFunctionTag*, RE::Actor* actor) {
        if (!actor) return;

        // TESNPC::GetSpellList() is proven in your existing ExportPlayerPreset code.
        // For a freshly spawned actor with no default spells, this list contains
        // exactly what SetRace() injected.
        auto* npc = actor->GetActorBase()->As<RE::TESNPC>();
        if (!npc) return;

        auto* spellData = npc->GetSpellList();
        if (!spellData || !spellData->spells || spellData->numSpells == 0) return;

        for (std::uint32_t i = 0; i < spellData->numSpells; ++i) {
            auto* spell = spellData->spells[i];
            if (!spell) continue;
            actor->RemoveSpell(spell);
        }
    }

    int32_t ProcessSellChest(RE::StaticFunctionTag*, RE::TESObjectREFR* junkChest, RE::TESObjectREFR* goldChest, float sellPct) {
        if (!junkChest || !goldChest) return 0;

        int32_t totalGold = 0;
        auto inventory = junkChest->GetInventory();
        std::vector<std::pair<RE::TESBoundObject*, int32_t>> itemsToRemove;

        for (auto& [item, data] : inventory) {
            if (!item || data.first <= 0) continue;
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
            auto goldForm = RE::TESForm::LookupByID<RE::TESObjectMISC>(0x0000000F);
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
        return RE::BSFixedString(GetLegacyDir().string().c_str());
    }

    RE::BSFixedString GetGamePathString(RE::StaticFunctionTag*) {
        return RE::BSFixedString(GetGamePath().string().c_str());
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

        auto srcJslot = GetCharGenPath(name);
        auto srcDds = GetCharGenTexturePath(name);

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

        // Derive character-specific filename early so it's in scope for everything
        auto player = RE::PlayerCharacter::GetSingleton();
        std::string safeName = "Unknown";
        if (player && player->GetActorBase() && player->GetActorBase()->GetName()) {
            safeName = SanitizeFileName(player->GetActorBase()->GetName());
        }
        std::string diskName = "PL_Slot" + std::to_string(slot) + "_" + safeName;

        auto dstJslot = legacyDir / (diskName + ".jslot");
        auto dstDds = legacyDir / (diskName + ".dds");

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

        if (!player) return 8;
        auto playerBase = player->GetActorBase();
        auto trueRace = player->GetRace();
        auto trueVoice = playerBase ? playerBase->voiceType : nullptr;
        bool isFemale = playerBase ? playerBase->GetSex() == RE::SEX::kFemale : false;
        const char* playerName = playerBase ? playerBase->GetName() : "";

        json data;
        data["slot"] = slot;
        data["slot_name"] = diskName;
        data["player_name"] = playerName ? playerName : "";
        data["bound"] = true;
        data["timestamp"] = std::time(nullptr);
        data["gender"] = isFemale ? "female" : "male";
        data["race_form_id"] = GetModFormID(trueRace);
        data["voice_form_id"] = GetModFormID(trueVoice);

        // --- Perks ---
        auto npc = playerBase ? playerBase->As<RE::TESNPC>() : nullptr;
        if (npc && npc->perks && npc->perkCount > 0) {
            for (std::uint32_t i = 0; i < npc->perkCount; ++i) {
                auto& perkData = npc->perks[i];
                if (!perkData.perk) continue;
                json p;
                p["form_id"] = GetModFormID(perkData.perk);
                p["name"] = perkData.perk->GetName() ? perkData.perk->GetName() : "";
                p["rank"] = perkData.currentRank;
                data["perks"].push_back(p);
            }
        }

        // --- Spells & Shouts ---
        auto* spellData = playerBase ? playerBase->GetSpellList() : nullptr;
        if (spellData) {
            if (spellData->spells && spellData->numSpells > 0) {
                for (std::uint32_t i = 0; i < spellData->numSpells; ++i) {
                    auto* spell = spellData->spells[i];
                    if (!spell) continue;
                    json s;
                    s["form_id"] = GetModFormID(spell);
                    s["name"] = spell->GetName() ? spell->GetName() : "";
                    data["spells"].push_back(s);
                }
            }
            if (spellData->shouts && spellData->numShouts > 0) {
                for (std::uint32_t i = 0; i < spellData->numShouts; ++i) {
                    auto* shout = spellData->shouts[i];
                    if (!shout) continue;
                    json s;
                    s["form_id"] = GetModFormID(shout);
                    s["name"] = shout->GetName() ? shout->GetName() : "";
                    data["shouts"].push_back(s);
                }
            }
        }

        // --- Inventory ---
        auto inv = player->GetInventory();
        for (auto& [item, countData] : inv) {
            if (!item) continue;
            json jItem;
            jItem["form_id"] = GetModFormID(item);
            jItem["name"] = item->GetName() ? item->GetName() : "";
            jItem["count"] = countData.first;
            data["inventory"].push_back(jItem);
        }

        // --- Equipment (worn armor + weapons) ---
        data["equipment"] = json::array();
        const uint32_t armorSlots[] = {
            0x00000001, 0x00000002, 0x00000004, 0x00000008,
            0x00000010, 0x00000080, 0x00000100, 0x00000200,
            0x00000800, 0x00001000
        };
        for (auto slotMask : armorSlots) {
            auto* armor = player->GetWornArmor(static_cast<RE::BGSBipedObjectForm::BipedObjectSlot>(slotMask));
            if (armor) {
                json item;
                item["form_id"] = GetModFormID(armor);
                item["name"] = armor->GetName() ? armor->GetName() : "";
                item["slot_mask"] = slotMask;
                item["is_weapon"] = false;
                data["equipment"].push_back(item);
            }
        }
        auto* rightHand = player->GetEquippedObject(false);
        if (rightHand) {
            json item;
            item["form_id"] = GetModFormID(rightHand);
            item["name"] = rightHand->GetName() ? rightHand->GetName() : "";
            item["is_weapon"] = true;
            auto* weap = rightHand->As<RE::TESObjectWEAP>();
            if (weap) item["weapon_type"] = static_cast<int>(weap->GetWeaponType());
            data["equipment"].push_back(item);
        }
        auto* leftHand = player->GetEquippedObject(true);
        if (leftHand && leftHand != rightHand) {
            json item;
            item["form_id"] = GetModFormID(leftHand);
            item["name"] = leftHand->GetName() ? leftHand->GetName() : "";
            item["is_weapon"] = true;
            auto* weap = leftHand->As<RE::TESObjectWEAP>();
            if (weap) item["weapon_type"] = static_cast<int>(weap->GetWeaponType());
            data["equipment"].push_back(item);
        }

        // --- Stats ---
        auto* avOwner = player->AsActorValueOwner();
        if (avOwner) {
            json stats;
            stats["level"] = player->GetLevel();
            stats["health_base"] = avOwner->GetBaseActorValue(RE::ActorValue::kHealth);
            stats["health_current"] = avOwner->GetActorValue(RE::ActorValue::kHealth);
            stats["magicka_base"] = avOwner->GetBaseActorValue(RE::ActorValue::kMagicka);
            stats["magicka_current"] = avOwner->GetActorValue(RE::ActorValue::kMagicka);
            stats["stamina_base"] = avOwner->GetBaseActorValue(RE::ActorValue::kStamina);
            stats["stamina_current"] = avOwner->GetActorValue(RE::ActorValue::kStamina);
            stats["carry_weight_base"] = avOwner->GetBaseActorValue(RE::ActorValue::kCarryWeight);
            stats["carry_weight_current"] = avOwner->GetActorValue(RE::ActorValue::kCarryWeight);
            stats["speed_mult"] = avOwner->GetActorValue(RE::ActorValue::kSpeedMult);

            json skills;
            skills["OneHanded"] = avOwner->GetBaseActorValue(RE::ActorValue::kOneHanded);
            skills["TwoHanded"] = avOwner->GetBaseActorValue(RE::ActorValue::kTwoHanded);
            skills["Archery"] = avOwner->GetBaseActorValue(RE::ActorValue::kArchery);
            skills["Block"] = avOwner->GetBaseActorValue(RE::ActorValue::kBlock);
            skills["Smithing"] = avOwner->GetBaseActorValue(RE::ActorValue::kSmithing);
            skills["HeavyArmor"] = avOwner->GetBaseActorValue(RE::ActorValue::kHeavyArmor);
            skills["LightArmor"] = avOwner->GetBaseActorValue(RE::ActorValue::kLightArmor);
            skills["Pickpocket"] = avOwner->GetBaseActorValue(RE::ActorValue::kPickpocket);
            skills["Lockpicking"] = avOwner->GetBaseActorValue(RE::ActorValue::kLockpicking);
            skills["Sneak"] = avOwner->GetBaseActorValue(RE::ActorValue::kSneak);
            skills["Alchemy"] = avOwner->GetBaseActorValue(RE::ActorValue::kAlchemy);
            skills["Speechcraft"] = avOwner->GetBaseActorValue(RE::ActorValue::kSpeech);
            skills["Alteration"] = avOwner->GetBaseActorValue(RE::ActorValue::kAlteration);
            skills["Conjuration"] = avOwner->GetBaseActorValue(RE::ActorValue::kConjuration);
            skills["Destruction"] = avOwner->GetBaseActorValue(RE::ActorValue::kDestruction);
            skills["Illusion"] = avOwner->GetBaseActorValue(RE::ActorValue::kIllusion);
            skills["Restoration"] = avOwner->GetBaseActorValue(RE::ActorValue::kRestoration);
            skills["Enchanting"] = avOwner->GetBaseActorValue(RE::ActorValue::kEnchanting);
            stats["skills"] = skills;
            data["stats"] = stats;
        }

        auto slotPath = GetSlotFile(slot);
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

    bool ClearSlot(RE::StaticFunctionTag*, int32_t slot, RE::BSFixedString slotName) {
        auto legacyDir = GetLegacyDir();
        auto slotFile = GetSlotFile(slot);
        std::string name = slotName.c_str();

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

    RE::BSFixedString GetSafeCharacterName(RE::StaticFunctionTag*) {
        auto player = RE::PlayerCharacter::GetSingleton();
        std::string name = player && player->GetActorBase() ? player->GetActorBase()->GetName() : "Unknown";
        return RE::BSFixedString(SanitizeFileName(name).c_str());
    }

    // --- Latency probe ---
    namespace {
        std::mutex g_latencyMutex;
        std::vector<double> g_latencySamples;
        std::atomic<bool> g_latencyRunning{ false };
        int g_latencyTarget = 30;
        std::chrono::steady_clock::time_point g_latencyLast;

        void LatencyCheckTask() {
            if (!g_latencyRunning.load()) return;

            auto now = std::chrono::steady_clock::now();
            bool continueSampling = false;

            {
                std::lock_guard<std::mutex> lock(g_latencyMutex);
                if (g_latencyLast.time_since_epoch().count() > 0) {
                    double ms = std::chrono::duration<double, std::milli>(now - g_latencyLast).count();
                    if (g_latencySamples.size() < static_cast<size_t>(g_latencyTarget)) {
                        g_latencySamples.push_back(ms);
                    }
                }
                g_latencyLast = now;

                if (g_latencySamples.size() < static_cast<size_t>(g_latencyTarget) && g_latencyRunning.load()) {
                    continueSampling = true;
                }
            }

            if (continueSampling) {
                SKSE::GetTaskInterface()->AddTask(&LatencyCheckTask);
                return;
            }

            g_latencyRunning = false;

            std::lock_guard<std::mutex> lock(g_latencyMutex);
            if (!g_latencySamples.empty()) {
                double avg = 0.0;
                double minMs = 999999.0;
                double maxMs = 0.0;
                for (auto v : g_latencySamples) {
                    avg += v;
                    if (v < minMs) minMs = v;
                    if (v > maxMs) maxMs = v;
                }
                avg /= g_latencySamples.size();

                spdlog::info("PL/Latency: Avg[{}ms] Min[{}ms] Max[{}ms] Samples[{}]",
                    static_cast<int>(avg), static_cast<int>(minMs), static_cast<int>(maxMs), g_latencySamples.size());
            }
        }
    }

    void StartLatencyCheck(RE::StaticFunctionTag*, int32_t a_samples) {
        std::lock_guard<std::mutex> lock(g_latencyMutex);
        g_latencySamples.clear();
        g_latencyTarget = std::clamp(a_samples, 1, 100);
        g_latencyLast = {};
        g_latencyRunning = true;
        SKSE::GetTaskInterface()->AddTask(&LatencyCheckTask);
    }

    bool IsLatencyCheckRunning(RE::StaticFunctionTag*) {
        return g_latencyRunning.load();
    }

    float GetLatencyAverage(RE::StaticFunctionTag*) {
        std::lock_guard<std::mutex> lock(g_latencyMutex);
        if (g_latencySamples.empty()) return 0.0f;
        double sum = 0.0;
        for (auto v : g_latencySamples) sum += v;
        return static_cast<float>(sum / g_latencySamples.size());
    }

    float GetLatencyMin(RE::StaticFunctionTag*) {
        std::lock_guard<std::mutex> lock(g_latencyMutex);
        if (g_latencySamples.empty()) return 0.0f;
        double minMs = 999999.0;
        for (auto v : g_latencySamples) {
            if (v < minMs) minMs = v;
        }
        return static_cast<float>(minMs);
    }

    float GetLatencyMax(RE::StaticFunctionTag*) {
        std::lock_guard<std::mutex> lock(g_latencyMutex);
        if (g_latencySamples.empty()) return 0.0f;
        double maxMs = 0.0;
        for (auto v : g_latencySamples) {
            if (v > maxMs) maxMs = v;
        }
        return static_cast<float>(maxMs);
    }

    bool RegisterFunctions(RE::BSScript::IVirtualMachine* vm) {
        // Return type: bool -> use true
        vm->RegisterFunction("IsSlotBound", "PL_StationScript", IsSlotBound, true);
        vm->RegisterFunction("ClearSlot", "PL_StationScript", ClearSlot, true);
        vm->RegisterFunction("StageSlotForLoad", "PL_VesselActor", StageSlotForLoad, true);
        vm->RegisterFunction("UnstageSlotAfterLoad", "PL_VesselActor", UnstageSlotAfterLoad, true);
        vm->RegisterFunction("ClearDefaultOutfit", "PL_VesselActor", ClearDefaultOutfit, true);
        vm->RegisterFunction("SetActorBaseSex", "PL_VesselActor", SetActorBaseSex, true);
        vm->RegisterFunction("IsSKSEPluginLoaded", "PL_ManagerQuest", IsSKSEPluginLoaded, true);
        vm->RegisterFunction("IsLatencyCheckRunning", "PL_LatencyCheck", IsLatencyCheckRunning, true);

        // Return type: BSFixedString -> use false
        vm->RegisterFunction("GetLegacyDirString", "PL_StationScript", GetLegacyDirString, false);
        vm->RegisterFunction("GetGamePathString", "PL_StationScript", GetGamePathString, false);
        vm->RegisterFunction("GetSafeCharacterName", "PL_StationScript", GetSafeCharacterName, false);

        // Return type: int32_t -> use false
        vm->RegisterFunction("ExportPlayerPreset", "PL_StationScript", ExportPlayerPreset, false);
        vm->RegisterFunction("ProcessSellChest", "BennyShelterSellChestScript", ProcessSellChest, false);

        // Return type: void -> use false
        vm->RegisterFunction("BreakPlayerAnimation", "PL_StationScript", BreakPlayerAnimation, false);
        vm->RegisterFunction("ClearPlayerAnimation", "PL_StationScript", ClearPlayerAnimation, false);
        vm->RegisterFunction("StartLatencyCheck", "PL_LatencyCheck", StartLatencyCheck, false);

        // Return type: float -> use false
        vm->RegisterFunction("GetLatencyAverage", "PL_LatencyCheck", GetLatencyAverage, false);
        vm->RegisterFunction("GetLatencyMin", "PL_LatencyCheck", GetLatencyMin, false);
        vm->RegisterFunction("GetLatencyMax", "PL_LatencyCheck", GetLatencyMax, false);

        spdlog::info("Project Legacy: Papyrus functions registered.");
        return true;
    }
}