Scriptname PL_StationScript extends ObjectReference
; ---------------------------------------------------------------------------
; invisible-until-summon architecture:
;   vessels are NEVER constructed or enabled at load. load only refreshes
;   the trigger's prompt from the registry. construction happens mid-game,
;   on a player activation — the exact conditions the bind path survives.
;   this removes the entire load-path DBD::DoReset3D crash surface.
;
; trigger prompt is the state indicator:
;   vacant  -> "Soul Sucker"     (activate = bind)
;   bound   -> "Summon <name>"   (activate = summon / lazy-construct)
; ---------------------------------------------------------------------------

int Property SlotIndex Auto
FormList Property PL_TriggerForms Auto
ObjectReference[] fxRefs  ; every glow/carrier this station spawned — the sweep list
int fxCount = 0

Function TrackFX(ObjectReference fx)
    if !fxRefs
        fxRefs = new ObjectReference[64]
        fxCount = 0
    endif
    if fx && fxCount < fxRefs.Length
        fxRefs[fxCount] = fx
        fxCount += 1
    endif
EndFunction
; ^ all PL_StationTrigger base forms, in slot order (trigger01 first).
; new property = old saves have NO baked value for it, so it always
; initializes from the esp — unlike SlotIndex, which saves BAKE IN.
; (char B's save had SlotIndex=1 baked from the duplicate-then-rename
; era; the esp fix to 6 never reached it. never trust baked props.)

Actor Property PlayerRef Auto
ActorBase Property PL_VesselBase Auto
Activator Property PL_PerkGlow Auto
ActorBase Property PL_InvisibleActor Auto
Actor Property SpawnedVessel Auto Hidden

Idle Property PL_AscendMale Auto
Idle Property PL_AscendFemale Auto

Message Property PL_MsgEmpty Auto
Message Property PL_MsgBindConfirm Auto
Message Property PL_MsgBindSuccess Auto
Message Property PL_MsgBindFail Auto
Message Property PL_MsgBound Auto
Message Property PL_MsgSummon Auto
Message Property PL_MsgCleanseConfirm Auto
Message Property PL_MsgBoundMenu Auto  ; Summon / Add to Story / Grow With Me (toggle) / Release / Leave

Keyword Property PL_VesselLink Auto
Keyword Property PL_GlowLink Auto

Quest Property MQ101 Auto  ; Unbound — ff's hard-won lesson: CharGen hangs on
; saves where the intro hasn't completed. gate every face load on it.

; wait until the game itself has finished initializing chargen state.
; bounded so LAL-style starts that skip MQ101 can't deadlock the bind.
Function WaitForCharGenReady()
    int safety = 120  ; up to 60s
    while MQ101 && !MQ101.IsCompleted() && safety > 0
        safety -= 1
        Utility.Wait(0.5)
    endWhile
    Debug.Trace("PL/Station " + SlotIndex + ": chargen gate — MQ101 completed=" + MQ101.IsCompleted() + " (" + (120 - safety) + " ticks)")
EndFunction

EffectShader Property PL_Blind01 Auto

EffectShader Property PL_BlindingLightGold Auto
VisualEffect Property PL_ValorFX Auto
VisualEffect Property PL_WarpTargetFX Auto
ImageSpaceModifier Property PL_FadeToWhite Auto
ImageSpaceModifier Property PL_FadeToWhiteHoldImod Auto
ImageSpaceModifier Property PL_FadeToWhiteBackImod Auto

EffectShader Property PL_ExtractionFlashWhite Auto
EffectShader Property PL_BlindingLightInwardParticles Auto
VisualEffect Property PL_FXGreybeardAbsorbEffect Auto
EffectShader Property PL_BlindingLightRed Auto

bool Function IsSlotBound(int slot) Global Native
bool Function GetSlotScale(int slot) Global Native
Function SetSlotScale(int slot, bool scale) Global Native
int Function ExportPlayerPreset(int slot, string slotName) Global Native
Function BreakPlayerAnimation(Actor akPlayer) Global Native
Function ClearPlayerAnimation(Actor akPlayer) Global Native
String Function GetSafeCharacterName() Global Native
bool Function ClearSlot(int slot, string slotName) Global Native
String Function GetSlotDiskName(int slot) Global Native
Form Function GetSlotRaceForm(int slot) Global Native
int Function GetSlotVesselSex(int slot) Global Native

; ---- derive the slot from the base form's position in PL_TriggerForms. ----
; esp data, immune to save-baking — a stale/misnumbered SlotIndex
; self-corrects the first time anyone sees or touches the stand.
Function ResolveSlotIndex()
    if !PL_TriggerForms
        return
    endif
    int idx = PL_TriggerForms.Find(self.GetBaseObject())
    if idx >= 0 && SlotIndex != idx + 1
        Debug.Trace("PL/Station: slot corrected " + SlotIndex + " -> " + (idx + 1) + " (baked property was stale)")
        SlotIndex = idx + 1
    endif
EndFunction

; ---- trigger prompt = state. name lives here, not on any mesh. ----
Function UpdateTriggerName()
    bool bound = IsSlotBound(SlotIndex)
    string boundName = GetSlotDiskName(SlotIndex)
    Debug.Trace("PL/Station " + SlotIndex + ": UpdateTriggerName — bound=" + bound + " name='" + boundName + "'")
    if bound && boundName != ""
        self.SetDisplayName("Summon " + boundName, true)
    else
        self.SetDisplayName("Soul Sucker", true)
    endif
EndFunction

Function UpdateVisualState()
    UpdateTriggerName()
    ObjectReference physicalPedestal = self.GetLinkedRef(PL_GlowLink)
    if IsSlotBound(SlotIndex)
        if PL_Blind01 && physicalPedestal
            PL_Blind01.Play(physicalPedestal, -1)
        endif
    else
        if PL_Blind01 && physicalPedestal
            PL_Blind01.Stop(physicalPedestal)
        endif
    endif
EndFunction

Event OnCellLoad()
    ; kept for completeness, but this event empirically NEVER fires on
    ; base-form scripted activators — OnLoad below is the reliable one
    ResolveSlotIndex()
    Debug.Trace("PL/Station " + SlotIndex + ": OnCellLoad fired")
    UpdateVisualState()
EndEvent

Event OnLoad()
    ; 3D-based event — proven to fire on these refs (the perk glow uses it).
    ; every stand renames itself when its model loads, no dependency on the
    ; manager's Stations array pointing at the same physical object
    ResolveSlotIndex()
    Debug.Trace("PL/Station " + SlotIndex + ": OnLoad fired")
    UpdateVisualState()
    ; once more after the load settles — the dll's registry reload can land
    ; AFTER this OnLoad, and a stale first read must not stick
    RegisterForSingleUpdate(6.0)
EndEvent

Event OnUpdate()
    Debug.Trace("PL/Station " + SlotIndex + ": OnUpdate rename refresh")
    UpdateVisualState()
    SweepStrayFX()
    RegisterForSingleUpdate(6.0)  ; heartbeat — this event PROVABLY fires, glow/carrier OnUpdates do not
EndEvent

; the graveyard shift. papyrus backstops ON the fx refs are dead — a ref
; blocked inside SplineTranslateToRef never services its own OnUpdate
; (zero OnUpdate traces across a 12 mb log, hundreds of registrations).
; so the station — whose heartbeat fires — sweeps its own spawn list
; instead. no extender needed: it spawned them, it remembers them.
Function SweepStrayFX()
    if !fxRefs
        return
    endif
    float now = Utility.GetCurrentRealTime()
    int i = 0
    while i < fxCount
        ObjectReference fx = fxRefs[i]
        if fx
            if fx.IsDeleted()
                fxRefs[i] = None  ; natural death — free the slot
            else
                float born = -1.0
                PL_PerkGlowScript glow = fx as PL_PerkGlowScript
                PL_GearCarrierScript car = fx as PL_GearCarrierScript
                if glow
                    born = glow.BornAt
                elseif car
                    born = car.BornAt
                endif
                if born > 0.0 && now - born > 15.0
                    fx.DisableNoWait()
                    fx.Delete()
                    fxRefs[i] = None
                    Debug.Trace("PL/Station " + SlotIndex + ": swept stray FX " + fx)
                endif
            endif
        endif
        i += 1
    endWhile
EndFunction

; ---- load path: registry check + prompt refresh. NO actor work, ever. ----
Function TryRestoreSlot()
    ResolveSlotIndex()
    if !IsSlotBound(SlotIndex)
        UpdateTriggerName()
        return
    endif
    Debug.Trace("PL/Station " + SlotIndex + ": bound (" + GetSlotDiskName(SlotIndex) + ") — vessel dormant until summon")
    UpdateVisualState()
EndFunction

; ---- full construction from the registry payload. runs ONLY on player ----
; ---- activation (summon), never at load. same law as DoBind.         ----
Actor Function ConstructVesselFromRegistry()
    string diskName = GetSlotDiskName(SlotIndex)
    Race slotRace = GetSlotRaceForm(SlotIndex) as Race
    Debug.Trace("PL/Station " + SlotIndex + ": lazy construct — name=" + diskName + " race=" + slotRace)

    ObjectReference spawnMarker = self.GetLinkedRef(PL_VesselLink)
    if !spawnMarker
        Debug.Trace("PL/Station " + SlotIndex + ": lazy construct — no spawn marker")
        return None
    endif
    if !slotRace
        slotRace = PlayerRef.GetActorBase().GetRace()
    endif

    ; born disabled — all surgery ghost-side, 3D builds once at Enable
    Actor vessel = spawnMarker.PlaceAtMe(PL_VesselBase, 1, true, true) as Actor
    SpawnedVessel = vessel
    if !vessel
        Debug.Trace("PL/Station " + SlotIndex + ": lazy construct — spawn failed")
        return None
    endif

    vessel.BlockActivation(true)
    vessel.SetRestrained(true)
    (vessel as PL_VesselActor).SlotIndex = SlotIndex
    (vessel as PL_VesselActor).myEchoName = diskName

    ; direct copy FIRST, ghost-side — sex/name/voice/gear/perks/spells/shouts
    ; land before the race-switch event and before any 3D exists.
    ; the json payload is authoritative, not the current player.
    bool bindOk = (vessel as PL_VesselActor).PerformBind(SlotIndex, diskName, diskName)
    Debug.Trace("PL/Station " + SlotIndex + ": lazy construct — PerformBind returned " + bindOk)

    ; race through the engine's front door so the hook stack gets notified
    vessel.SetRace(slotRace)
    ; RE-ASSERT sex — SetRace can clobber the flag PerformBind set (the
    ; she-male relapse: female preset applied to a male body hangs skee)
    PL_VesselActor.SetActorBaseSex(vessel, GetSlotVesselSex(SlotIndex))

    vessel.Enable()
    vessel.EnableAI(false)

    int safety3D = 100
    while !vessel.Is3DLoaded() && safety3D > 0
        safety3D -= 1
        Utility.Wait(0.1)
    endWhile
    Debug.Trace("PL/Station " + SlotIndex + ": lazy construct — 3D built after " + (100 - safety3D) + " ticks")

    ; KISS: same stripped flow as DoBind — stage, load, unstage. nothing else.
    if diskName != ""
        PL_VesselActor.StageSlotForLoad(SlotIndex, diskName)
        PL_VesselActor.AcquireCharGenLock()  ; same turnstile as DoBind
        Debug.Trace("PL/Station " + SlotIndex + ": lazy construct — staged, calling LoadCharacter")
        Bool faceOk = CharGen.LoadCharacter(vessel, slotRace, diskName)
        Debug.Trace("PL/Station " + SlotIndex + ": lazy construct — LoadCharacter returned " + faceOk)
        Int iSafety = 5
        while !faceOk && iSafety > 0
            iSafety -= 1
            Utility.Wait(0.5)
            faceOk = CharGen.LoadCharacter(vessel, slotRace, diskName)
        endWhile
        PL_VesselActor.ReleaseCharGenLock()
        PL_VesselActor.UnstageSlotAfterLoad(SlotIndex, diskName)
        Debug.Trace("PL/Station " + SlotIndex + ": lazy construct — LoadCharacter ok=" + faceOk)
        if !faceOk
            Debug.Notification("Project Legacy: Face load failed for " + diskName)
        endif
    endif

    ; stats last — SetRace/LoadCharacter recalc AVs, copy after they're done
    (vessel as PL_VesselActor).ApplyStats(SlotIndex, diskName)
    return vessel
EndFunction

bool Function DoBind()
    Game.ForceThirdPerson()

    String slotName = "PL_Slot" + SlotIndex
    CharGen.SaveCharacter(slotName)
    Utility.Wait(1.5)
    Debug.Trace("PL/Bind 1: SaveCharacter fired")

    String safeName = GetSafeCharacterName()
    String diskName = safeName

    int result = ExportPlayerPreset(SlotIndex, slotName)
    Debug.Trace("PL/Bind 2: ExportPlayerPreset result=" + result)
    if result != 0
        return false
    endif

    Game.DisablePlayerControls(abMovement = true, abFighting = true, abCamSwitch = true, abLooking = false, abSneaking = true, abMenu = true, abActivate = true, abJournalTabs = false)

    Idle ascendIdle
    if PlayerRef.GetActorBase().GetSex() == 0
        ascendIdle = PL_AscendMale
    else
        ascendIdle = PL_AscendFemale
    endif

    PlayerRef.PlayIdle(ascendIdle)
    Utility.Wait(0.8)

    if PL_ExtractionFlashWhite
        PL_ExtractionFlashWhite.Play(PlayerRef, -1)
    endif
    if PL_ValorFX
        PL_ValorFX.Play(PlayerRef, -1)
    endif
    if PL_BlindingLightInwardParticles
        PL_BlindingLightInwardParticles.Play(PlayerRef, 2.0)
    endif
    Utility.Wait(1.5)

    if PL_FXGreybeardAbsorbEffect
        PL_FXGreybeardAbsorbEffect.Play(PlayerRef, 2.5)
    endif
    Utility.Wait(1.2)

    if PL_ExtractionFlashWhite
        PL_ExtractionFlashWhite.Stop(PlayerRef)
    endif
    if PL_BlindingLightInwardParticles
        PL_BlindingLightInwardParticles.Stop(PlayerRef)
    endif
    if PL_FXGreybeardAbsorbEffect
        PL_FXGreybeardAbsorbEffect.Stop(PlayerRef)
    endif
    if PL_ValorFX
        PL_ValorFX.Stop(PlayerRef)
    endif

    ; no fullscreen fade — player keeps their screen, ff-style
    Debug.Trace("PL/Bind 3: FX done")

    ObjectReference spawnMarker = self.GetLinkedRef(PL_VesselLink)
    ; born disabled — all surgery ghost-side, 3D builds once at Enable
    Actor vessel = spawnMarker.PlaceAtMe(PL_VesselBase, 1, true, true) as Actor
    SpawnedVessel = vessel
    Debug.Trace("PL/Bind 4: spawned (disabled), vessel=" + vessel)
    if !vessel
        Game.EnablePlayerControls()
        return false
    endif

    vessel.BlockActivation(true)
    vessel.SetRestrained(true)
    (vessel as PL_VesselActor).SlotIndex = SlotIndex
    (vessel as PL_VesselActor).myEchoName = safeName

    ; direct copy FIRST — sex/name/voice/gear/perks/spells/shouts land
    ; ghost-side before the race-switch event and before any 3D exists
        ; visuals listen while the dll copies
    RegisterForModEvent("PL_EquipmentSaved", "OnPLEquipmentSaved")
    RegisterForModEvent("PL_PerkSaved", "OnPLPerkSaved")
    RegisterForModEvent("PL_SpellSaved", "OnPLSpellSaved")
    bool bindOk = (vessel as PL_VesselActor).PerformBind(SlotIndex, diskName, safeName)
    Debug.Trace("PL/Bind 5: PerformBind returned " + bindOk)
    UnregisterForModEvent("PL_EquipmentSaved")
    UnregisterForModEvent("PL_PerkSaved")
    UnregisterForModEvent("PL_SpellSaved")

    ; race through the engine's front door so the hook stack gets notified
    vessel.SetRace(PlayerRef.GetActorBase().GetRace())
    ; RE-ASSERT sex — SetRace can clobber the flag PerformBind set
    PL_VesselActor.SetActorBaseSex(vessel, GetSlotVesselSex(SlotIndex))
    Debug.Trace("PL/Bind 6: SetRace done (engine path), sex re-asserted")

    ; born as the ghost — the white silhouette IS the clone mid-copy
    vessel.SetGhost(true)
    vessel.Enable()
    int safety3D = 100
    while !vessel.Is3DLoaded() && safety3D > 0
        safety3D -= 1
        Utility.Wait(0.1)
    endWhile
    Debug.Trace("PL/Bind 7: 3D built after " + (100 - safety3D) + " ticks")

    ; face snaps under the ghost shader — never visible
    ; KISS: this is the 6149d99 flow, the one that bound gurl and dez.
    ; mq101 gate, facegen delete, naked-first, dds games — all added during
    ; the petunia hunt, none ever fixed anything, all stripped.
    if diskName != ""
        PL_VesselActor.StageSlotForLoad(SlotIndex, diskName)
        PL_VesselActor.AcquireCharGenLock()  ; ff's busy-lock — one chargen load at a time, mod-wide
        Bool faceOk = CharGen.LoadCharacter(vessel, PlayerRef.GetActorBase().GetRace(), diskName)
        Int iSafety = 5
        while !faceOk && iSafety > 0
            iSafety -= 1
            Utility.Wait(0.5)
            faceOk = CharGen.LoadCharacter(vessel, PlayerRef.GetActorBase().GetRace(), diskName)
        endWhile
        PL_VesselActor.ReleaseCharGenLock()
        PL_VesselActor.UnstageSlotAfterLoad(SlotIndex, diskName)
        Debug.Trace("PL/Bind 8: LoadCharacter ok=" + faceOk)

        if !faceOk
            Debug.Notification("Project Legacy: Face load failed for " + diskName)
        endif
    endif

    ; stats last — SetRace/LoadCharacter recalc AVs, copy after they're done
    (vessel as PL_VesselActor).ApplyStats(SlotIndex, diskName)

    ; the white bursts — stats visual, local to the clone
    if PL_BlindingLightGold
        PL_BlindingLightGold.Play(vessel, 3.0)
    endif
    if PL_BlindingLightRed
        PL_BlindingLightRed.Play(vessel, 3.0)
    endif
    if PL_WarpTargetFX
        PL_WarpTargetFX.Play(vessel, 3.0)
    endif
    Utility.Wait(1.5)

    ; solidify for a beat so the player sees the finished clone...
    vessel.SetGhost(false)
    vessel.EnableAI(false)
    Debug.Trace("PL/Bind 9: solidified")

    Utility.Wait(2.0)

    ; ...then she returns to the stand. vessels stay dormant until summoned —
    ; the soul is stored, not standing around. brief fade-out as she goes.
    if PL_BlindingLightGold
        PL_BlindingLightGold.Play(vessel, 2.0)
    endif
    Utility.Wait(0.8)
    vessel.Disable()
    Debug.Trace("PL/Bind 9b: vessel dormant (invisible-until-summon)")

    BreakPlayerAnimation(PlayerRef)
    Utility.Wait(0.3)
    ClearPlayerAnimation(PlayerRef)

    Game.EnablePlayerControls()
    UpdateVisualState()
    Debug.Trace("PL/Bind 10: complete")
    return true
EndFunction


Function DoSummon()
    Debug.Trace("PL/Station " + SlotIndex + ": DoSummon entered")
    Actor vessel = SpawnedVessel

    if vessel && vessel.IsDead()
        Debug.Trace("PL/Station " + SlotIndex + ": vessel is DEAD — rebuilding from payload")
        vessel.Delete()
        SpawnedVessel = None
        vessel = None
    endif

    if !vessel
        ; lazy construction — first summon in this save. mid-game, on a
        ; player action: the exact conditions the bind path survives.
        Debug.Trace("PL/Station " + SlotIndex + ": no vessel — lazy construct from registry")
        vessel = ConstructVesselFromRegistry()
        if !vessel
            Debug.Notification("Project Legacy: Summon failed — could not construct vessel")
            return
        endif
    endif

    Debug.Trace("PL/Station " + SlotIndex + ": calling SummonVessel on " + vessel)
    (vessel as PL_VesselActor).SummonVessel(PlayerRef, self)
    Debug.Trace("PL/Station " + SlotIndex + ": SummonVessel returned")

    ; scale mode: payload stats applied during construction — now overwrite
    ; them with the CURRENT player's. runs every summon, so she tracks your
    ; growth even mid-save, no menu visit needed
    if GetSlotScale(SlotIndex)
        (vessel as PL_VesselActor).ApplyStatsFromPlayer()
        Debug.Trace("PL/Station " + SlotIndex + ": scale mode — stats matched to player")
    endif
EndFunction

; ---- re-capture the player's CURRENT state into this slot's payload. ----
; the clone is a snapshot; this refreshes it. vessels rebuild from the
; payload at every summon, so updating the payload updates the clone in
; EVERY save automatically. guarded: only the original character may update.
Function DoUpdate()
    string boundName = GetSlotDiskName(SlotIndex)
    string safeName = GetSafeCharacterName()
    if safeName != boundName
        Debug.Notification("Not your face. Not your call.")
        return
    endif

    string slotName = "PL_Slot" + SlotIndex
    CharGen.SaveCharacter(slotName)  ; overwrites the face preset
    Utility.Wait(1.5)
    int result = ExportPlayerPreset(SlotIndex, slotName)  ; overwrites gear/perks/spells/shouts/stats json
    if result != 0
        Debug.Notification("Project Legacy: Update failed.")
        return
    endif

    ; kill any existing vessel so the next summon rebuilds from the new data
    Actor vessel = SpawnedVessel
    if vessel
        vessel.Delete()
        SpawnedVessel = None
    endif
    Debug.Trace("PL/Station " + SlotIndex + ": payload updated by " + safeName)
    Debug.Notification("Story updated. She's you again — current you, unfortunately.")
EndFunction

Function DoCleanse()
    Actor vessel = SpawnedVessel
    if vessel
        (vessel as PL_VesselActor).CleanseVessel()
        vessel.Delete()
        SpawnedVessel = None
    endif

    String diskName = GetSlotDiskName(SlotIndex)
    ClearSlot(SlotIndex, diskName)
    UpdateVisualState()
EndFunction

Event OnActivate(ObjectReference akActionRef)
    if akActionRef != PlayerRef
        return
    endif

    ResolveSlotIndex()

    if !IsSlotBound(SlotIndex)
        UpdateVisualState()
        int btn = PL_MsgEmpty.Show()
        if btn == 0
            int confirm = PL_MsgBindConfirm.Show()
            if confirm == 0
                bool bOk = DoBind()
                if bOk
                    PL_MsgBindSuccess.Show()
                else
                    PL_MsgBindFail.Show()
                endif
            endif
        endif
    else
        ; bound — offer the menu. button order must match PL_MsgBoundMenu in
        ; the esp: 0=Summon, 1=Add to Story (update), 2=Grow With Me (scale
        ; toggle), 3=Release (cleanse), 4=Leave
        int btn = PL_MsgBoundMenu.Show()
        if btn == 0
            DoSummon()
        elseif btn == 1
            DoUpdate()
        elseif btn == 2
            ; scale toggle — per-slot, rides the registry, applies at summon
            bool scale = !GetSlotScale(SlotIndex)
            SetSlotScale(SlotIndex, scale)
            if scale
                Debug.Notification("Alright, yeeted. She's your co-pilot now, gods help you.")
            else
                Debug.Notification("Back to her own story. Yours was getting predictable.")
            endif
        elseif btn == 3
            int confirm = PL_MsgCleanseConfirm.Show()
            if confirm == 0
                DoCleanse()
            endif
        endif
    endif
EndEvent

Event OnPLEquipmentSaved(string eventName, string strArg, float numArg, Form sender)
    if !(sender as Armor) && !(sender as Weapon)
        return
    endif
    ; skip body-slot (32) armor in the fly visual — a cuirass on an invisible
    ; carrier reads as a hollow BODY parked at the stand, not as flying gear
    Armor akArmor = sender as Armor
    if akArmor && Math.LogicalAnd(akArmor.GetSlotMask(), 0x4)
        return
    endif
    ObjectReference spawnMarker = self.GetLinkedRef(PL_VesselLink)
    ; invisible body — only the equipped gear renders, exactly like ff.
    ; no SetGhost: the "ghost" was never a person, it's the gear itself
    Actor carrier = spawnMarker.PlaceAtMe(PL_InvisibleActor, 1, true, true) as Actor
    if !carrier
        return
    endif
    (carrier as PL_GearCarrierScript).BornAt = Utility.GetCurrentRealTime()
    TrackFX(carrier)
    carrier.EnableAI(false)
    carrier.Enable()
    int cSafety = 50
    while !carrier.Is3DLoaded() && cSafety > 0
        cSafety -= 1
        Utility.Wait(0.1)
    endWhile
    carrier.RemoveAllItems()
    carrier.AddItem(sender, 1, true)
    carrier.EquipItem(sender, false, true)
    carrier.SetAlpha(0.01, false)
    carrier.MoveTo(PlayerRef)
    carrier.SetAlpha(1.0, true)
    PL_BlindingLightGold.Play(carrier, 0.5)
    ; linger on the player, then fly slow enough to track —
    ; 350-800 u/s was a blur; the only piece ever SEEN was a stuck one
    Utility.Wait(Utility.RandomFloat(1.0, 2.2))
    carrier.SplineTranslateToRef(spawnMarker, Utility.RandomFloat(160.0, 380.0), 250.0, 10.0)
    Utility.Wait(3.0)
    carrier.Delete()
EndEvent
Event OnPLPerkSaved(string eventName, string strArg, float numArg, Form sender)
    ObjectReference spawnMarker = self.GetLinkedRef(PL_VesselLink)
    PL_PerkGlowScript glow = spawnMarker.PlaceAtMe(PL_PerkGlow, 1, true, true) as PL_PerkGlowScript
    if glow
        glow.BornAt = Utility.GetCurrentRealTime()
        TrackFX(glow)
        glow.StartNode = "NPC Head [Head]"
        glow.Target = PlayerRef
        glow.FlyTo = spawnMarker
        glow.EnableNoWait(true)
        Debug.Trace("PL/FX: perk glow spawned")
    endif
EndEvent

Event OnPLSpellSaved(string eventName, string strArg, float numArg, Form sender)
    ObjectReference spawnMarker = self.GetLinkedRef(PL_VesselLink)
    PL_PerkGlowScript glow = spawnMarker.PlaceAtMe(PL_PerkGlow, 1, true, true) as PL_PerkGlowScript
    if glow
        if Utility.RandomInt(0, 1)
            glow.StartNode = "NPC L Hand [LHnd]"
        else
            glow.StartNode = "NPC R Hand [RHnd]"
        endif
        glow.BornAt = Utility.GetCurrentRealTime()
        TrackFX(glow)
        glow.Target = PlayerRef
        glow.FlyTo = spawnMarker
        glow.EnableNoWait(true)
        Debug.Trace("PL/FX: spell glow spawned, node=" + glow.StartNode)
    endif
EndEvent
