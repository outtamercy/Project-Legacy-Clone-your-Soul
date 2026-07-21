Scriptname PL_StationScript extends ObjectReference

int Property SlotIndex Auto
Actor Property PlayerRef Auto

Idle Property PL_AscendMale Auto
Idle Property PL_AscendFemale Auto

Message Property PL_MsgEmpty Auto
Message Property PL_MsgBindConfirm Auto
Message Property PL_MsgBindSuccess Auto
Message Property PL_MsgBindFail Auto
Message Property PL_MsgBound Auto
Message Property PL_MsgCleanseConfirm Auto

Keyword Property PL_VesselLink Auto

; --- FX properties matching FF ---
EffectShader Property PL_BlindingLightGold Auto      ; the gold glow
VisualEffect Property PL_ValorFX Auto                ; blue wisps
VisualEffect Property PL_WarpTargetFX Auto           ; warp ring
ImageSpaceModifier Property PL_FadeToWhite Auto
ImageSpaceModifier Property PL_FadeToWhiteBackImod Auto

bool Function IsSlotBound(int slot) Global Native
int Function ExportPlayerPreset(int slot, string slotName) Global Native
bool Function ClearSlot(int slot) Global Native
Function BreakPlayerAnimation(Actor akPlayer) Global Native
Function ClearPlayerAnimation(Actor akPlayer) Global Native

bool Function DoBind()
    Actor vessel = self.GetLinkedRef(PL_VesselLink) as Actor
    if !vessel
        return false
    endif
    
    String slotName = "PL_Slot" + SlotIndex
    CharGen.SaveCharacter(slotName)
    Utility.Wait(2.0)
    
    int result = ExportPlayerPreset(SlotIndex, slotName)
    if result != 0
        Game.EnablePlayerControls()
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
    
    if !vessel.IsEnabled()
        vessel.Enable(false)
    endif
    vessel.SetRestrained(true)
    vessel.BlockActivation(true)
    vessel.SetAlpha(0.25, false)
    
    ; FF-style FX sequence
    if PL_BlindingLightGold
        PL_BlindingLightGold.Play(PlayerRef, 3.0)
    endif
    if PL_ValorFX
        PL_ValorFX.Play(PlayerRef, 3.0)
    endif
    if PL_WarpTargetFX
        PL_WarpTargetFX.Play(vessel, 3.0)
    endif
    
    Utility.Wait(2.5)
    
    if PL_FadeToWhite
        PL_FadeToWhite.Apply()
    endif
    Utility.Wait(1.2)
    
    (vessel as PL_VesselActor).BindVessel(slotName, PlayerRef.GetActorBase().GetRace(), PlayerRef.GetVoiceType())
    (vessel as PL_VesselActor).CopyGearFrom(PlayerRef)
    
    if PL_FadeToWhite && PL_FadeToWhiteBackImod
        PL_FadeToWhite.PopTo(PL_FadeToWhiteBackImod)
    endif
    
    ; Ground snap
    BreakPlayerAnimation(PlayerRef)
    Utility.Wait(0.5)
    ClearPlayerAnimation(PlayerRef)
    
    vessel.SetAlpha(1.0, false)
    Game.EnablePlayerControls()
    
    return true
EndFunction

Function DoSummon()
    Actor vessel = self.GetLinkedRef(PL_VesselLink) as Actor
    if !vessel
        return
    endif
    (vessel as PL_VesselActor).SummonVessel(PlayerRef, self)
EndFunction

Function DoCleanse()
    Actor vessel = self.GetLinkedRef(PL_VesselLink) as Actor
    if !vessel
        return
    endif
    (vessel as PL_VesselActor).CleanseVessel()
    ClearSlot(SlotIndex)
EndFunction

Event OnActivate(ObjectReference akActionRef)
    if akActionRef != PlayerRef
        return
    endif
    
    int btn = PL_MsgEmpty.Show()
    if btn != 0
        return
    endif
    
    if !IsSlotBound(SlotIndex)
        int confirm = PL_MsgBindConfirm.Show()
        if confirm == 0
            bool bOk = DoBind()
            if bOk
                PL_MsgBindSuccess.Show()
            else
                PL_MsgBindFail.Show()
            endif
        endif
    else
        int actionBtn = PL_MsgBound.Show()
        if actionBtn == 0
            DoSummon()
        elseIf actionBtn == 1
            Actor vessel = self.GetLinkedRef(PL_VesselLink) as Actor
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