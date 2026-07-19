#include <SKSE/SKSE.h>
#include "log.h"
#include "Papyrus.h"

bool CallPapyrusMethod(RE::TESObjectREFR* ref, const char* scriptName, const char* funcName) {
    auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
    if (!vm) return false;
    auto* policy = vm->GetObjectHandlePolicy();
    if (!policy) return false;
    auto handle = policy->GetHandleForObject(ref->GetFormType(), ref);
    if (!handle) return false;
    RE::BSTSmartPointer<RE::BSScript::Object> obj;
    if (!vm->FindBoundObjectForObject(handle, scriptName, obj)) return false;
    RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
    vm->DispatchMethodCall(obj, funcName, nullptr, callback);
    return true;
}

class LoadGameHandler : public RE::BSTEventSink<RE::TESLoadGameEvent> {
public:
    virtual RE::BSEventNotifyControl ProcessEvent(const RE::TESLoadGameEvent*, RE::BSTEventSource<RE::TESLoadGameEvent>*) override {
        auto* formList = RE::TESForm::LookupByEditorID<RE::BGSListForm>("PL_StationList");
        if (!formList) return RE::BSEventNotifyControl::kContinue;
        formList->ForEachForm([&](RE::TESForm& form) {
            auto* station = form.As<RE::TESObjectREFR>();
            if (station) CallPapyrusMethod(station, "PL_StationScript", "TryRestoreSlot");
            return true;
            });
        return RE::BSEventNotifyControl::kContinue;
    }
};
static LoadGameHandler g_loadHandler;

SKSEPluginLoad(const SKSE::LoadInterface* skse) {
    SKSE::Init(skse); SetupLog();
    struct JCNG_API_V1 {
        int version;
        Handle(*jmap_object)();
        void (*jmap_set_int)(Handle, const char*, int32_t);
        int32_t(*jmap_get_int)(Handle, const char*, int32_t);
        // ... etc
    };
    static JCNG_API_V1* g_jcng = nullptr;

    void QueryJCNG() {
        auto* msg = SKSE::GetMessagingInterface();
        if (!msg) return;
        msg->Dispatch('JCAP', &g_jcng, sizeof(g_jcng), "JContainersNG");
        if (g_jcng) spdlog::info("PL: JCNG API v{} linked", g_jcng->version);
    }

    // === INSERT HERE ===
    auto serial = SKSE::GetSerializationInterface();
    serial->SetUniqueID('JCON');
    serial->SetSaveCallback(SaveCallback);
    serial->SetLoadCallback(LoadCallback);
    serial->SetRevertCallback(RevertCallback);

    auto messaging = SKSE::GetMessagingInterface();
    if (messaging) {
        messaging->RegisterListener([](SKSE::MessagingInterface::Message* msg) {
            if (msg->type == SKSE::MessagingInterface::kPreLoadGame) {
                PL::ImportSlotRegistry();
            }
            else if (msg->type == SKSE::MessagingInterface::kNewGame) {
                PL::ImportSlotRegistry();
            }
            });
    }
    // === END INSERT ===

    auto* eventSource = RE::ScriptEventSourceHolder::GetSingleton()->GetEventSource<RE::TESLoadGameEvent>();
    if (eventSource) eventSource->AddEventSink(&g_loadHandler);
    auto papyrus = SKSE::GetPapyrusInterface();
    if (!papyrus) return false;
    if (!papyrus->Register(ProjectLegacy::Papyrus::RegisterFunctions)) return false;
    spdlog::info("Project Legacy: loaded");
    return true;
}

extern "C" DLLEXPORT constinit auto SKSEPlugin_Version = []() {
    SKSE::PluginVersionData v;
    v.PluginVersion({ 0, 5, 0, 0 });
    v.PluginName("ProjectLegacy");
    v.UsesAddressLibrary(true);
    v.UsesNoStructs(false);
    v.CompatibleVersions({ SKSE::RUNTIME_SSE_LATEST, SKSE::RUNTIME_VR });
    return v;
    }();