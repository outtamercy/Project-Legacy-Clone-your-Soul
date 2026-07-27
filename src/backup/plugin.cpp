#include <SKSE/SKSE.h>
#include "log.h"
#include "Papyrus.h"
#include "PL_Persistence.h"

// on every game load: refresh the disk registry (jcng rebuilds its db on
// load, so the handle from boot is stale — without this the registry reads
// garbage). restoring stations is PAPYRUS's job via the load-game alias and
// its settle delay — this handler used to dispatch TryRestoreSlot directly,
// which fired full actor construction inside the load storm and raced the
// alias. never again. registry only.
class LoadGameHandler : public RE::BSTEventSink<RE::TESLoadGameEvent> {
public:
    virtual RE::BSEventNotifyControl ProcessEvent(const RE::TESLoadGameEvent*, RE::BSTEventSource<RE::TESLoadGameEvent>*) override {
        PL::ReloadRegistry();
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
                if (PL::LinkJCNG()) {
                    PL::ReloadRegistry();  // boot read: existing PL_Registry.json
                }
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
