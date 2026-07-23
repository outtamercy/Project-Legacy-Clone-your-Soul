#include "Papyrus.h"
#include "PL_Persistence.h"
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

RE::TESForm* DecodeModFormID(const std::string& str) {
    auto pipe = str.find("|0x");
    if (pipe == std::string::npos) return nullptr;
    std::string modName = str.substr(0, pipe);
    std::string localIDStr = str.substr(pipe + 3);
    try {
        uint32_t localID = std::stoul(localIDStr, nullptr, 16);
        auto* dh = RE::TESDataHandler::GetSingleton();
        if (!dh) return nullptr;
        if (modName.empty()) return RE::TESForm::LookupByID(localID);
        return dh->LookupForm(localID, modName);
    }
    catch (...) { return nullptr; }
}

namespace ProjectLegacy::Papyrus {

    // --- Native Instance Alignment Fixes ---
    static void SendPLModEvent(RE::TESForm* sender, const char* eventName) {
        auto* source = SKSE::GetModCallbackEventSource();
        if (!source) return;
        SKSE::ModCallbackEvent ev(eventName, "", 0.0f, sender);
        source->SendEvent(&ev);
    }

    bool ApplyPlayerPreset(RE::Actor* self, int32_t slot) {
        auto* vessel = self;
        if (!vessel) {
            spdlog::error("PL: ApplyPlayerPreset — null vessel self pointer");
            return false;
        }

        if (!PL::IsSlotBound(slot)) {
            spdlog::error("PL: ApplyPlayerPreset — Slot {} is unbound, cannot apply preset", slot);
            return false;
        }

        std::string diskName = PL::GetSlotCharName(slot);
        RE::TESForm* raceForm = PL::GetSlotRaceForm(slot);
        int sex = PL::GetSlotSex(slot);

        if (diskName.empty() || !raceForm) {
            spdlog::error("PL: ApplyPlayerPreset — Invalid disk metadata for slot {}", slot);
            return false;
        }

        auto* race = raceForm->As<RE::TESRace>();
        if (!race) return false;

        // Execute the exact metadata logic on the bound instance
        auto npc = vessel->GetActorBase();
        if (npc) {
            if (sex == 1) {
                npc->actorData.actorBaseFlags.set(RE::ACTOR_BASE_DATA::Flag::kFemale);
            }
            else {
                npc->actorData.actorBaseFlags.reset(RE::ACTOR_BASE_DATA::Flag::kFemale);
            }
        }

        if (vessel->GetRace() != race) {
            // fork's RE::Actor has no SetRace — poke the base's race form
            // directly. script side still does the live Actor.SetRace call
            if (npc) {
                npc->race = race;
            }
        }

        return true;
    }

    bool ApplyPlayerGear(RE::Actor* self, int32_t slot) {
        auto* vessel = self;
        if (!vessel) {
            spdlog::error("PL: ApplyPlayerGear — null vessel self pointer");
            return false;
        }
        if (!PL::IsSlotBound(slot)) return false;

        auto jsonPath = GetLegacyDir() / (PL::GetSlotCharName(slot) + ".json");
        if (!fs::exists(jsonPath)) {
            spdlog::warn("PL: ApplyPlayerGear — no gear payload for slot {}", slot);
            return false;
        }
        json data;
        try { std::ifstream f(jsonPath.wstring()); f >> data; }
        catch (...) { return false; }

        auto* equipMgr = RE::ActorEquipManager::GetSingleton();
        int equipped = 0, added = 0, skipped = 0;
        if (data.contains("inventory")) {
            for (auto& jItem : data["inventory"]) {
                auto* form = DecodeModFormID(jItem.value("form_id", ""));
                auto* bound = form ? form->As<RE::TESBoundObject>() : nullptr;
                if (!bound) { skipped++; continue; }  // mod gone between saves — shrug, log, move on
                int32_t count = jItem.value("count", 1);
                bool worn = jItem.value("worn", false);
                // breadcrumb — if we die mid-gear, the last line names the item
                spdlog::info("PL: gear item {} x{} worn={}", jItem.value("form_id", ""), count, worn);
                vessel->AddObjectToContainer(bound, nullptr, count, nullptr);
                added++;
                // old snapshots have no "worn" flag — they restore as inventory-only
                if (equipMgr && worn) {
                    equipMgr->EquipObject(vessel, bound, nullptr, static_cast<std::uint32_t>(count), nullptr, true, true, false, false);
                    equipped++;
                }
            }
        }
        spdlog::info("PL: ApplyPlayerGear — slot {}: {} added, {} equipped, {} skipped (dead forms)", slot, added, equipped, skipped);
        return true;
    }

    bool PerformBind(RE::Actor* vessel, int32_t slot, std::string slotName, std::string echoName) {
        auto* player = RE::PlayerCharacter::GetSingleton();
        auto* npc = vessel ? vessel->GetActorBase() : nullptr;
        if (!player || !npc) {
            spdlog::error("PL: PerformBind — bad args (vessel={})", (void*)vessel);
            return false;
        }

        // ---- identity, ghost-side. vessel is disabled, no 3D exists,
        // nothing here may touch the scene graph — writes only, one pass ----

        // sex: plain ACBS flag write. proven safe since the fossil era,
        // and it lands AFTER papyrus SetRace by call order, so no clobber
        auto sex = player->GetActorBase()->GetSex();
        if (sex == RE::SEX::kFemale) {
            npc->actorData.actorBaseFlags.set(RE::ACTOR_BASE_DATA::Flag::kFemale);
        }
        else {
            npc->actorData.actorBaseFlags.reset(RE::ACTOR_BASE_DATA::Flag::kFemale);
        }

        // race: deliberately NOT written here. ApplyPlayerPreset's npc->race
        // poke is what poisoned the rebuild chain — hooks (DBD et al.) read
        // that base data on every 3D reset. race goes through papyrus
        // SetRace, the engine's own path. don't re-add it. ever.

        // name: cosmetic, face-gen doesn't read it. voice is set after the
        // json parse below — captured voice first, hardcoded as fallback
        npc->fullName = echoName.c_str();
        spdlog::info("PL: PerformBind — identity done for '{}'", echoName);

        // ---- gear: file name from the caller, registry as backup ----
        std::string charName = slotName;
        if (charName.empty()) {
            charName = PL::GetSlotCharName(slot);
        }
        if (charName.empty() || charName == "None") {
            spdlog::warn("PL: PerformBind — slot {} has no name, gear skipped", slot);
            return true;  // identity still applied — not a failure
        }
        auto file = GetLegacyDir() / (charName + ".json");

        std::ifstream ifs(file);
        if (!ifs) {
            spdlog::warn("PL: PerformBind — no gear payload at {}", file.string());
            return true;
        }
        json data;
        try {
            data = json::parse(ifs);
        }
        catch (const std::exception& e) {
            spdlog::error("PL: PerformBind — json parse failed: {}", e.what());
            return true;
        }

        // voice: prefer the captured one — the hardcoded fallback voices may
        // lack follower dialogue, which is the "can't talk" symptom
        if (data.contains("voice_form_id")) {
            auto* voiceForm = DecodeModFormID(data.value("voice_form_id", ""));
            auto* capturedVoice = voiceForm ? voiceForm->As<RE::BGSVoiceType>() : nullptr;
            if (capturedVoice) {
                npc->voiceType = capturedVoice;
            }
            else {
                auto* voice = RE::TESForm::LookupByID<RE::BGSVoiceType>(sex == RE::SEX::kFemale ? 0x00013543 : 0x00013577);
                if (voice) {
                    npc->voiceType = voice;
                }
            }
        }
        else {
            auto* voice = RE::TESForm::LookupByID<RE::BGSVoiceType>(sex == RE::SEX::kFemale ? 0x00013543 : 0x00013577);
            if (voice) {
                npc->voiceType = voice;
            }
        }

        auto* equipMgr = RE::ActorEquipManager::GetSingleton();
        int added = 0, equipped = 0, skipped = 0;
        if (data.contains("inventory")) {
            for (auto& jItem : data["inventory"]) {
                auto* form = DecodeModFormID(jItem.value("form_id", ""));
                auto* bound = form ? form->As<RE::TESBoundObject>() : nullptr;
                if (!bound) { skipped++; continue; }  // mod gone between saves — shrug, move on
                int32_t count = jItem.value("count", 1);
                bool worn = jItem.value("worn", false);
                vessel->AddObjectToContainer(bound, nullptr, count, nullptr);
                added++;
                if (equipMgr && worn) {
                    equipMgr->EquipObject(vessel, bound, nullptr, static_cast<std::uint32_t>(count), nullptr, true, true, false, false);
                    equipped++;
                    SendPLModEvent(bound, "PL_EquipmentSaved");
                }
            }
        }
        spdlog::info("PL: PerformBind — slot {}: {} added, {} equipped, {} skipped", slot, added, equipped, skipped);
        // ---- perks / spells / shouts: same direct-copy pass, ghost-side ----
        int perks = 0, spells = 0, shouts = 0;
        if (data.contains("perks")) {
            for (auto& jPerk : data["perks"]) {
                auto* form = DecodeModFormID(jPerk.value("form_id", ""));
                if (form && form->GetFormType() == RE::FormType::Perk) {
                    vessel->AddPerk(form->As<RE::BGSPerk>());
                    perks++;
                    SendPLModEvent(form, "PL_PerkSaved");
                }
            }
        }
        if (data.contains("spells")) {
            for (auto& jSpell : data["spells"]) {
                auto* form = DecodeModFormID(jSpell.value("form_id", ""));
                if (form && form->GetFormType() == RE::FormType::Spell) {
                    vessel->AddSpell(form->As<RE::SpellItem>());
                    spells++;
                    SendPLModEvent(form, "PL_SpellSaved");
                }
            }
        }
        if (data.contains("shouts")) {
            for (auto& jShout : data["shouts"]) {
                auto* form = DecodeModFormID(jShout.value("form_id", ""));
                if (form && form->GetFormType() == RE::FormType::Shout) {
                    vessel->AddShout(form->As<RE::TESShout>());
                    shouts++;
                }
            }
        }
        spdlog::info("PL: PerformBind — slot {}: {} perks, {} spells, {} shouts copied", slot, perks, spells, shouts);

        return true;
    }
    bool ApplyStats(RE::Actor* vessel, int32_t slot, std::string slotName) {
        if (!vessel) {
            spdlog::error("PL: ApplyStats — null vessel");
            return false;
        }
        std::string charName = slotName;
        if (charName.empty()) { charName = PL::GetSlotCharName(slot); }
        if (charName.empty() || charName == "None") {
            spdlog::warn("PL: ApplyStats — slot {} has no name, skipped", slot);
            return true;
        }
        auto file = GetLegacyDir() / (charName + ".json");
        std::ifstream ifs(file);
        if (!ifs) {
            spdlog::warn("PL: ApplyStats — no payload at {}", file.string());
            return true;
        }
        json data;
        try { data = json::parse(ifs); }
        catch (const std::exception& e) {
            spdlog::error("PL: ApplyStats — json parse failed: {}", e.what());
            return true;
        }
        auto* vav = vessel->AsActorValueOwner();
        if (!vav || !data.contains("stats")) {
            spdlog::warn("PL: ApplyStats — no stats block in {}", file.string());
            return true;
        }
        auto& st = data["stats"];
        int applied = 0;
        auto setBase = [&](const char* key, RE::ActorValue av) {
            if (st.contains(key)) {
                vav->SetBaseActorValue(av, st[key].get<float>());
                applied++;
            }
            };
        setBase("health_base", RE::ActorValue::kHealth);
        setBase("magicka_base", RE::ActorValue::kMagicka);
        setBase("stamina_base", RE::ActorValue::kStamina);
        setBase("carry_weight_base", RE::ActorValue::kCarryWeight);
        if (st.contains("skills")) {
            static const std::pair<const char*, RE::ActorValue> kSkills[] = {
                { "OneHanded",   RE::ActorValue::kOneHanded },
                { "TwoHanded",   RE::ActorValue::kTwoHanded },
                { "Archery",     RE::ActorValue::kArchery },
                { "Block",       RE::ActorValue::kBlock },
                { "Smithing",    RE::ActorValue::kSmithing },
                { "HeavyArmor",  RE::ActorValue::kHeavyArmor },
                { "LightArmor",  RE::ActorValue::kLightArmor },
                { "Pickpocket",  RE::ActorValue::kPickpocket },
                { "Lockpicking", RE::ActorValue::kLockpicking },
                { "Sneak",       RE::ActorValue::kSneak },
                { "Alchemy",     RE::ActorValue::kAlchemy },
                { "Speechcraft", RE::ActorValue::kSpeech },
                { "Alteration",  RE::ActorValue::kAlteration },
                { "Conjuration", RE::ActorValue::kConjuration },
                { "Destruction", RE::ActorValue::kDestruction },
                { "Illusion",    RE::ActorValue::kIllusion },
                { "Restoration", RE::ActorValue::kRestoration },
                { "Enchanting",  RE::ActorValue::kEnchanting },
            };
            for (auto& [key, av] : kSkills) {
                if (st["skills"].contains(key)) {
                    vav->SetBaseActorValue(av, st["skills"][key].get<float>());
                    applied++;
                }
            }
        }
        spdlog::info("PL: ApplyStats — slot {}: {} actor values copied", slot, applied);
        return true;
    }


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
            if (ec) return 5;
        }

        auto srcJslot = GetCharGenPath(name);
        auto srcDds = GetCharGenTexturePath(name);

        int attempts = 60;
        while ((!fs::exists(srcJslot) || !fs::exists(srcDds)) && attempts > 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
            attempts--;
        }

        if (!fs::exists(srcJslot)) return 1;
        if (!fs::exists(srcDds)) return 2;

        auto player = RE::PlayerCharacter::GetSingleton();
        std::string safeName = "Unknown";
        if (player && player->GetActorBase() && player->GetActorBase()->GetName()) {
            safeName = SanitizeFileName(player->GetActorBase()->GetName());
        }
        std::string diskName = safeName;  // ff-style: files keyed by char name, not slot number

        auto dstJslot = legacyDir / (diskName + ".jslot");
        auto dstDds = legacyDir / (diskName + ".dds");

        fs::copy_file(srcJslot, dstJslot, fs::copy_options::overwrite_existing, ec);
        if (ec) return 3;
        fs::remove(srcJslot, ec);

        fs::copy_file(srcDds, dstDds, fs::copy_options::overwrite_existing, ec);
        if (ec) return 4;
        fs::remove(srcDds, ec);

        if (!player) return 8;
        auto playerBase = player->GetActorBase();
        auto trueRace = player->GetRace();
        auto trueVoice = playerBase ? playerBase->voiceType : nullptr;
        bool isFemale = playerBase ? playerBase->GetSex() == RE::SEX::kFemale : false;
        const char* playerName = playerBase ? playerBase->GetName() : "";

        // Keep local filesystem tracking up to date alongside the database
        PL::SetSlotBound(slot, diskName, isFemale ? 1 : 0, trueRace, GetModFormID(trueRace));

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
        }
        // --- Shouts ---
        if (spellData && spellData->shouts && spellData->numShouts > 0) {
            for (std::uint32_t i = 0; i < spellData->numShouts; ++i) {
                auto* shout = spellData->shouts[i];
                if (!shout) continue;
                json s;
                s["form_id"] = GetModFormID(shout);
                s["name"] = shout->GetName() ? shout->GetName() : "";
                data["shouts"].push_back(s);
            }
        }

        // --- Stats (backup schema, named keys) ---
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

        // --- Inventory & Worn Outfits ---
        auto inv = player->GetInventory();
        for (auto& [item, countData] : inv) {
            if (!item) continue;
            json jItem;
            jItem["form_id"] = GetModFormID(item);
            jItem["name"] = item->GetName() ? item->GetName() : "";
            jItem["count"] = countData.first;
            jItem["worn"] = countData.second && countData.second->IsWorn();
            data["inventory"].push_back(jItem);
        }

        auto slotPath = GetLegacyDir() / (diskName + ".json");
        std::ofstream f(slotPath.wstring(), std::ios::out | std::ios::trunc);
        if (!f.is_open()) return 6;

        f << data.dump(4);
        f.flush();
        bool failed = f.fail();
        f.close();

        return failed ? 7 : 0;
    }

    bool ClearSlot(RE::StaticFunctionTag*, int32_t slot, RE::BSFixedString) {
        auto legacyDir = GetLegacyDir();
        // name comes from the registry — whoever the player is right now
        // has zero say in which files die
        std::string name = PL::GetSlotCharName(slot);
        std::error_code ec;
        if (!name.empty()) {
            fs::remove(legacyDir / (name + ".json"), ec);
            fs::remove(legacyDir / (name + ".jslot"), ec);
            fs::remove(legacyDir / (name + ".dds"), ec);
        }
        PL::ClearSlot(slot);
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

        if (fs::exists(srcJslot)) fs::copy_file(srcJslot, dstJslot, fs::copy_options::overwrite_existing, ec);
        if (fs::exists(srcDds)) fs::copy_file(srcDds, dstDds, fs::copy_options::overwrite_existing, ec);
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

    bool IsSKSEPluginLoaded(RE::StaticFunctionTag*) { return true; }

    RE::BSFixedString GetSafeCharacterName(RE::StaticFunctionTag*) {
        auto player = RE::PlayerCharacter::GetSingleton();
        std::string name = player && player->GetActorBase() ? player->GetActorBase()->GetName() : "Unknown";
        return RE::BSFixedString(SanitizeFileName(name).c_str());
    }

    RE::BSFixedString GetSlotDiskName(RE::StaticFunctionTag*, int32_t slot) {
        return RE::BSFixedString(PL::GetSlotCharName(slot).c_str());
    }

    RE::TESForm* GetSlotRaceForm(RE::StaticFunctionTag*, int32_t slot) {
        if (auto* form = PL::GetSlotRaceForm(slot)) return form;
        // jcng nulled it (mod gone since bind) — try the string before giving up
        auto str = PL::GetSlotRaceString(slot);
        return str.empty() ? nullptr : DecodeModFormID(str);
    }

    int32_t GetSlotVesselSex(RE::StaticFunctionTag*, int32_t slot) {
        return PL::GetSlotSex(slot);
    }

    bool IsSlotBound(RE::StaticFunctionTag*, int32_t slot) {
        return PL::IsSlotBound(slot);
    }

    // --- Latency Tracker Namespace ---
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

    bool IsLatencyCheckRunning(RE::StaticFunctionTag*) { return g_latencyRunning.load(); }
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
        for (auto v : g_latencySamples) if (v < minMs) minMs = v;
        return static_cast<float>(minMs);
    }
    float GetLatencyMax(RE::StaticFunctionTag*) {
        std::lock_guard<std::mutex> lock(g_latencyMutex);
        if (g_latencySamples.empty()) return 0.0f;
        double maxMs = 0.0;
        for (auto v : g_latencySamples) if (v > maxMs) maxMs = v;
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
        vm->RegisterFunction("GetSlotDiskName", "PL_StationScript", GetSlotDiskName, false);
        vm->RegisterFunction("GetSlotRaceForm", "PL_StationScript", GetSlotRaceForm, false);
        vm->RegisterFunction("GetSlotVesselSex", "PL_StationScript", GetSlotVesselSex, false);

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

        // New vessel natives — instance methods on PL_VesselActor
        vm->RegisterFunction("ApplyPlayerPreset", "PL_VesselActor", ApplyPlayerPreset, false);
        vm->RegisterFunction("ApplyPlayerGear", "PL_VesselActor", ApplyPlayerGear, false);
        vm->RegisterFunction("PerformBind", "PL_VesselActor", PerformBind, false);
        vm->RegisterFunction("ApplyStats", "PL_VesselActor", ApplyStats, false);

        spdlog::info("Project Legacy: Papyrus functions registered.");
        return true;
    }
}  // namespace ProjectLegacy::Papyrus