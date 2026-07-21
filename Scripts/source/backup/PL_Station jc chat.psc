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

Function UpdateVisualState()
    ; Grab the physical pedestal linked to THIS trigger instance.
    ; self is the trigger box — the EFSH needs actual geometry to project onto.
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

bool Function DoBind()
    Game.ForceThirdPerson()
    
    String slotName = "PL_Slot" + SlotIndex
    CharGen.SaveCharacter(slotName)
    Utility.Wait(2.0)
    
    String safeName = GetSafeCharacterName()
    String diskName = "PL_Slot" + SlotIndex + "_" + safeName
    
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
    Utility.Wait(1.5)
    
    ; --- PHASE 1-4: ALL FX ON PLAYER ONLY (FF pattern) ---
    if PL_ExtractionFlashWhite
        PL_ExtractionFlashWhite.Play(PlayerRef, -1)
    endif
    if PL_ValorFX
        PL_ValorFX.Play(PlayerRef, -1)
    endif
    
    if PL_BlindingLightInwardParticles
        PL_BlindingLightInwardParticles.Play(PlayerRef, 3.0)
    endif
    Utility.Wait(3.0)
    
    if PL_FXGreybeardAbsorbEffect
        PL_FXGreybeardAbsorbEffect.Play(PlayerRef, 4.0)
    endif
    Utility.Wait(2.0)
    
    ; --- PHASE 5: WHITEOUT + PHYSICAL BIRTH ---
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
    Utility.Wait(2.0)
    if PL_FadeToWhiteHoldImod
        PL_FadeToWhiteHoldImod.Apply()
    endif
    if PL_FadeToWhite
        PL_FadeToWhite.Remove()
    endif
    
    ; Spawn vessel while player is blind
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
    
    (vessel as PL_VesselActor).BindVessel(diskName, PlayerRef.GetActorBase().GetRace())
    (vessel as PL_VesselActor).CopyGearFrom(PlayerRef)
    
    ; Let the race swap swirly burn out while still invisible
    Utility.Wait(5.0)
    vessel.RegenerateHead()
    Utility.Wait(0.5)
    
    ; Freeze the brain. The swirly fired during the wait above.
    vessel.EnableAI(false)
    
    ; --- PHASE 6: REVEAL ---
    if PL_FadeToWhiteHoldImod
        PL_FadeToWhiteHoldImod.Remove()
    endif
    if PL_FadeToWhiteBackImod
        PL_FadeToWhiteBackImod.Apply()
    endif
    
    if PL_BlindingLightGold
        PL_BlindingLightGold.Play(vessel, 5.0)
    endif
    if PL_BlindingLightRed
        PL_BlindingLightRed.Play(vessel, 5.0)
    endif
    if PL_WarpTargetFX
        PL_WarpTargetFX.Play(vessel, 5.0)
    endif
    
    BreakPlayerAnimation(PlayerRef)
    Utility.Wait(0.5)
    ClearPlayerAnimation(PlayerRef)
    
    Game.EnablePlayerControls()
    
    ; Update this station's glow now that it's bound
    UpdateVisualState()
    
    return true
EndFunction

Function DoSummon()
    Actor vessel = SpawnedVessel
    if !vessel || vessel.IsDead()
        ; ObjectReference script properties don't persist across saves.
        ; If you reloaded, the vessel pointer is gone. Rebind to respawn.
        Debug.Notification("Project Legacy: Vessel not found — rebind required after reload")
        return
    endif
    (vessel as PL_VesselActor).SummonVessel(PlayerRef, self)
EndFunction

Function DoCleanse()
    Actor vessel = SpawnedVessel
    if vessel
        (vessel as PL_VesselActor).CleanseVessel()
        vessel.Delete()
        SpawnedVessel = None
    endif
    
    String safeName = GetSafeCharacterName()
    String diskName = "PL_Slot" + SlotIndex + "_" + safeName
    ClearSlot(SlotIndex, diskName)
    
    ; Kill the glow since this slot is now empty
    UpdateVisualState()
EndFunction

Event OnActivate(ObjectReference akActionRef)
    if akActionRef != PlayerRef
        return
    endif
    
    ; Sync glow state when player approaches
    UpdateVisualState()
    
    ; Check slot state FIRST, then show the right menu
    if !IsSlotBound(SlotIndex)
        ; Slot is empty — show the bind menu
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
        ; Slot is bound — show the summon/dismiss/cleanse menu
        int actionBtn = PL_MsgBound.Show()
        if actionBtn == 0
            DoSummon()
        elseIf actionBtn == 1
            Actor vessel = SpawnedVessel
            if vessel
                (vessel as PL_VesselActor).DismissVessel()
            endif
        elseIf actionBtn == 2
            int confirm = PL_MsgCleanseConfirm.Show()
            if confirm == 0
                DoCleanse()
            endif
        endif
    endif
EndEvent