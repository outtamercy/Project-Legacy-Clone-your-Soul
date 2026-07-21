Scriptname PL_StationScript extends ObjectReference

int Property SlotIndex Auto
Actor Property PlayerRef Auto
ActorBase Property PL_VesselBase Auto
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

Keyword Property PL_VesselLink Auto
Keyword Property PL_GlowLink Auto

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
int Function ExportPlayerPreset(int slot, string slotName) Global Native
Function BreakPlayerAnimation(Actor akPlayer) Global Native
Function ClearPlayerAnimation(Actor akPlayer) Global Native
String Function GetSafeCharacterName() Global Native
bool Function ClearSlot(int slot, string slotName) Global Native
String Function GetSlotDiskName(int slot) Global Native
int Function GetSlotRaceForm(int slot) Global Native
int Function GetSlotVesselSex(int slot) Global Native

Function UpdateVisualState()
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

Function TryRestoreSlot()
    if !IsSlotBound(SlotIndex)
        return
    endif
    
    string diskName = GetSlotDiskName(SlotIndex)
    int raceForm = GetSlotRaceForm(SlotIndex)
    int slotSex = GetSlotVesselSex(SlotIndex)
    Debug.Trace("PL/Station " + SlotIndex + ": restore — name=" + diskName + " raceForm=" + raceForm + " sex=" + slotSex)
    
    ObjectReference spawnMarker = self.GetLinkedRef(PL_VesselLink)
    if !spawnMarker
        Debug.Trace("PL/Station " + SlotIndex + ": restore — no spawn marker")
        return
    endif
    
    ; same architecture as DoBind — born (or parked) disabled, surgery
    ; ghost-side, 3D builds once at Enable
    Actor vessel = SpawnedVessel
    if !vessel
        vessel = spawnMarker.PlaceAtMe(PL_VesselBase, 1, true, true) as Actor
        SpawnedVessel = vessel
    endif
    if !vessel
        Debug.Trace("PL/Station " + SlotIndex + ": restore — spawn failed")
        return
    endif
    if !vessel.IsDisabled()
        vessel.Disable()
    endif
    
    Race slotRace = Game.GetFormEx(raceForm) as Race
    if !slotRace
        slotRace = PlayerRef.GetActorBase().GetRace()
    endif
    
    ; race through the engine's front door, then one dll pass for the rest
    vessel.SetRace(slotRace)
    (vessel as PL_VesselActor).SlotIndex = SlotIndex
    bool bindOk = (vessel as PL_VesselActor).PerformBind(SlotIndex, diskName, diskName)
    Debug.Trace("PL/Station " + SlotIndex + ": restore — PerformBind returned " + bindOk)
    
    vessel.BlockActivation(true)
    vessel.SetRestrained(true)
    vessel.Enable()
    
    int safety3D = 100
    while !vessel.Is3DLoaded() && safety3D > 0
        safety3D -= 1
        Utility.Wait(0.1)
    endWhile
    Debug.Trace("PL/Station " + SlotIndex + ": restore — 3D built after " + (100 - safety3D) + " ticks")
    
    if diskName != ""
        PL_VesselActor.StageSlotForLoad(SlotIndex, diskName)
        Bool faceOk = CharGen.LoadCharacter(vessel, slotRace, diskName)
        Int iSafety = 5
        while !faceOk && iSafety > 0
            iSafety -= 1
            Utility.Wait(0.5)
            faceOk = CharGen.LoadCharacter(vessel, slotRace, diskName)
        endWhile
        PL_VesselActor.UnstageSlotAfterLoad(SlotIndex, diskName)
        Debug.Trace("PL/Station " + SlotIndex + ": restore — LoadCharacter ok=" + faceOk)
    endif
    
    vessel.EnableAI(false)
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
    if PL_ValorFX
        PL_ValorFX.Stop(PlayerRef)
    endif
    
    Debug.Trace("PL/Bind 3: FX done, fading")
    if PL_FadeToWhite
        PL_FadeToWhite.Apply()
    endif
    Utility.Wait(1.0)
    if PL_FadeToWhiteHoldImod
        PL_FadeToWhiteHoldImod.Apply()
    endif
    if PL_FadeToWhite
        PL_FadeToWhite.Remove()
    endif
    
    ObjectReference spawnMarker = self.GetLinkedRef(PL_VesselLink)
    ; born disabled — all surgery happens ghost-side, 3D builds once at Enable
    Actor vessel = spawnMarker.PlaceAtMe(PL_VesselBase, 1, true, true) as Actor
    SpawnedVessel = vessel
    Debug.Trace("PL/Bind 4: spawned (disabled), vessel=" + vessel)
    if !vessel
        if PL_FadeToWhiteHoldImod
            PL_FadeToWhiteHoldImod.Remove()
        endif
        if PL_FadeToWhiteBackImod
            PL_FadeToWhiteBackImod.Apply()
        endif
        Game.EnablePlayerControls()
        return false
    endif
    
    vessel.BlockActivation(true)
    vessel.SetRestrained(true)
    (vessel as PL_VesselActor).SlotIndex = SlotIndex
    
    ; race through the engine's front door so the hook stack gets notified
    vessel.SetRace(PlayerRef.GetActorBase().GetRace())
    Debug.Trace("PL/Bind 5: SetRace done (engine path)")
    
    ; identity + gear: one controlled pass in the dll
    bool bindOk = (vessel as PL_VesselActor).PerformBind(SlotIndex, diskName, safeName)
    Debug.Trace("PL/Bind 6: PerformBind returned " + bindOk)
    
    ; wake him — the one and only skeleton build of the whole bind
    vessel.Enable()
    int safety3D = 100
    while !vessel.Is3DLoaded() && safety3D > 0
        safety3D -= 1
        Utility.Wait(0.1)
    endWhile
    Debug.Trace("PL/Bind 7: 3D built after " + (100 - safety3D) + " ticks")
    
    ; face: papyrus till the SKEE interface phase lands
    if diskName != ""
        PL_VesselActor.StageSlotForLoad(SlotIndex, diskName)
        Bool faceOk = CharGen.LoadCharacter(vessel, PlayerRef.GetActorBase().GetRace(), diskName)
        Int iSafety = 5
        while !faceOk && iSafety > 0
            iSafety -= 1
            Utility.Wait(0.5)
            faceOk = CharGen.LoadCharacter(vessel, PlayerRef.GetActorBase().GetRace(), diskName)
        endWhile
        PL_VesselActor.UnstageSlotAfterLoad(SlotIndex, diskName)
        Debug.Trace("PL/Bind 8: LoadCharacter ok=" + faceOk)
        if !faceOk
            Debug.Notification("Project Legacy: Face load failed for " + diskName)
        endif
    endif
    
    vessel.EnableAI(false)
    
    if PL_FadeToWhiteHoldImod
        PL_FadeToWhiteHoldImod.Remove()
    endif
    if PL_FadeToWhiteBackImod
        PL_FadeToWhiteBackImod.Apply()
    endif
    
    if PL_BlindingLightGold
        PL_BlindingLightGold.Play(vessel, 3.0)
    endif
    if PL_BlindingLightRed
        PL_BlindingLightRed.Play(vessel, 3.0)
    endif
    if PL_WarpTargetFX
        PL_WarpTargetFX.Play(vessel, 3.0)
    endif
    
    BreakPlayerAnimation(PlayerRef)
    Utility.Wait(0.3)
    ClearPlayerAnimation(PlayerRef)
    
    Game.EnablePlayerControls()
    UpdateVisualState()
    Debug.Trace("PL/Bind 9: complete")
    return true
EndFunction

Function DoSummon()
    Debug.Trace("PL/Station " + SlotIndex + ": DoSummon entered")
    Actor vessel = SpawnedVessel
    Debug.Trace("PL/Station " + SlotIndex + ": SpawnedVessel = " + vessel)
    if !vessel
        Debug.Trace("PL/Station " + SlotIndex + ": vessel is NONE — bailing")
        Debug.Notification("Project Legacy: Vessel not found — rebind required after reload")
        return
    endif
    if vessel.IsDead()
        Debug.Trace("PL/Station " + SlotIndex + ": vessel is DEAD — bailing")
        Debug.Notification("Project Legacy: Vessel not found — rebind required after reload")
        return
    endif
    Debug.Trace("PL/Station " + SlotIndex + ": calling SummonVessel on " + vessel)
    (vessel as PL_VesselActor).SummonVessel(PlayerRef, self)
    Debug.Trace("PL/Station " + SlotIndex + ": SummonVessel returned")
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
    
    UpdateVisualState()
    
    if !IsSlotBound(SlotIndex)
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
        ; bound — "What now?" IS the menu. 0 = summon, anything else = walk away
        int actionBtn = PL_MsgSummon.Show()
        if actionBtn == 0
            DoSummon()
        endif
    endif
EndEvent