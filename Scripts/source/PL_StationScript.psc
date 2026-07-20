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
Form Function GetSlotRaceForm(int slot) Global Native
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

    ObjectReference spawnMarker = self.GetLinkedRef(PL_VesselLink)
    if !spawnMarker
        return
    endif

    ; identity comes from the registry, NOT the current player — restoring
    ; under a different character must still bring back the original clone
    String diskName = GetSlotDiskName(SlotIndex)
    Race slotRace = GetSlotRaceForm(SlotIndex) as Race
    int slotSex = GetSlotVesselSex(SlotIndex)
    Debug.Trace("PL/Station " + SlotIndex + ": restore — name=" + diskName + " sex=" + slotSex + " race=" + slotRace)

    Actor vessel = SpawnedVessel
    if !vessel
        vessel = spawnMarker.PlaceAtMe(PL_VesselBase, 1, true, false) as Actor
        SpawnedVessel = vessel
    endif
    if !vessel
        return
    endif

    ; runtime actorbase edits (race/sex/name/face) evaporate on load, so the
    ; ref survived but the clone didn't — re-run the whole bind on it
    vessel.BlockActivation(true)
    vessel.SetRestrained(true)
    vessel.EnableAI(false)
    (vessel as PL_VesselActor).SlotIndex = SlotIndex
    (vessel as PL_VesselActor).BindVessel(diskName, slotRace, slotSex, diskName)
    ; restore path never cleared the CK default outfit — bind path does it
    ; inside CopyGearFrom, we gotta do it ourselves here
    PL_VesselActor.ClearDefaultOutfit(vessel)
    vessel.RemoveAllItems(None, true, true)
    (vessel as PL_VesselActor).ApplyPlayerGear(SlotIndex)
    ; UpdateWeight no-ops when weight's unchanged — force the 3D rebuild or
    ; she keeps the male spawn body under the female face
    vessel.QueueNiNodeUpdate()
    vessel.EnableAI(false)
    UpdateVisualState()
EndFunction

bool Function DoBind()
    Game.ForceThirdPerson()
    
    String slotName = "PL_Slot" + SlotIndex
    CharGen.SaveCharacter(slotName)
    Utility.Wait(1.5)
    
    String safeName = GetSafeCharacterName()
    String diskName = safeName
    
    int result = ExportPlayerPreset(SlotIndex, slotName)
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
    Actor vessel = spawnMarker.PlaceAtMe(PL_VesselBase, 1, true, false) as Actor
    SpawnedVessel = vessel
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
    
    ; Fire structural vessel parameters first, then pass down copy sequences
    (vessel as PL_VesselActor).SlotIndex = SlotIndex
    (vessel as PL_VesselActor).BindVessel(diskName, PlayerRef.GetActorBase().GetRace(), PlayerRef.GetActorBase().GetSex(), safeName)
    (vessel as PL_VesselActor).CopyGearFrom(PlayerRef)
    
    Utility.Wait(2.5)
    vessel.RegenerateHead()
    Utility.Wait(0.3)
    
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