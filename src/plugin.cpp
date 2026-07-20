#include <SKSE/SKSE.h>
#include "log.h"
#include "Papyrus.h"
#include "PL_Persistence.h"

bool CallPapyrusMethod(RE::TESObjectREFR* ref, const char* scriptName, const char* funcName) {
    auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
    if (!vm) return false;
    auto* policy = vm->GetObjectHandlePolicy();
    if (!policy) return false;
    auto handle = policy->GetHandleForObject(ref->GetFormType(), ref);
    if (!handle) return false;
    RE::BSTSmartPointer<RE::BSScript::Object> obj;
    if (!vm->FindBoundObject(handle, scriptName, obj)) return false;
    RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
    vm->DispatchMethodCall(obj, funcName, nullptr, callback);
    return true;
}

class LoadGameHandler : public RE::BSTEventSink<RE::TESLoadGameEvent> {
public:
    virtual RE::BSEventNotifyControl ProcessEvent(const RE::TESLoadGameEvent*, RE::BSTEventSource<RE::TESLoadGameEvent>*) override {
        auto* formList = RE::TESForm::LookupByEditorID<RE::BGSListForm>("PL_StationList");
        if (!formList) return RE::BSEventNotifyControl::kContinue;
        formList->ForEachForm([&](RE::TESForm* form) {
            auto* station = form ? form->As<RE::TESObjectREFR>() : nullptr;
            if (station) CallPapyrusMethod(station, "PL_StationScript", "TryRestoreSlot");
            return RE::BSContainer::ForEachResult::kContinue;
            });
        return RE::BSEventNotifyControl::kContinue;
    }
};
static LoadGameHandler g_loadHandler;

SKSEPluginLoad(const SKSE::LoadInterface* skse) {
    SKSE::Init(skse); SetupLog();

    auto messaging = SKSE::GetMessagingInterface();
    if (messaging) {
        messaging->RegisterListener([](SKSE::MessagingInterface::Message* msg) {
            // grab jcng's api straight from their dll export once every
            // plugin is loaded — no messaging weirdness involved
            if (msg->type == SKSE::MessagingInterface::kPostPostLoad) {
                PL::LinkJCNG();
            }
            });
    }

    auto* eventSource = RE::ScriptEventSourceHolder::GetSingleton()->GetEventSource<RE::TESLoadGameEvent>();
    if (eventSource) eventSource->AddEventSink(&g_loadHandler);
    auto papyrus = SKSE::GetPapyrusInterface();
    if (!papyrus) return false;
    if (!papyrus->Register(ProjectLegacy::Papyrus::RegisterFunctions)) return false;
    spdlog::info("Project Legacy: loaded");
    return true;
}