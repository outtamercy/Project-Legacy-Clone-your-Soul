Scriptname PL_VesselActor extends Actor

Import Utility

int Property SlotIndex Auto
VisualEffect Property PL_ValorFX Auto
EffectShader Property PL_BlindingLightGold Auto
VisualEffect Property PL_WarpTargetFX Auto
Faction Property PotentialFollowerFaction Auto

String Property myEchoName Auto

String mySlotName
Race myVesselRace
VoiceType myVesselVoice
int myVesselSex

ObjectReference Property HomeStation Auto

bool Function StageSlotForLoad(int slot, string slotName) Global Native
bool Function UnstageSlotAfterLoad(int slot, string slotName) Global Native
bool Function ClearDefaultOutfit(Actor target) Global Native
bool Function SetActorBaseSex(Actor target, int sex) Global Native

; Kimi's Fix: Dropped Global modifier to ensure true instance handling mapping
bool Function ApplyPlayerPreset(int slot) Native
bool Function ApplyPlayerGear(int slot) Native
bool Function PerformBind(int slot, string slotName, string echoName) Native
bool Function ApplyStats(int slot, string slotName) Native

Function BindVessel(String slotName, Race vesselRace, int vesselSex, String echoName)
    Debug.Trace("PL/BindVessel 1: entered, race=" + vesselRace + " sex=" + vesselSex)
    mySlotName = slotName
    myVesselRace = vesselRace
    myVesselSex = vesselSex
    
    ; drop him off-stage (no-op on a fresh disabled spawn, kills 3D on restore)
    self.Disable()
    
    ; all base surgery happens while he's a ghost record — no 3D, no rebuild,
    ; no coin flips with death
    if myVesselRace && self.GetRace() != myVesselRace
        self.SetRace(myVesselRace)
        Debug.Trace("PL/BindVessel 2: SetRace done (ghost-side)")
    endif
    SetActorBaseSex(self, myVesselSex)
    bool presetOk = ApplyPlayerPreset(SlotIndex)
    Debug.Trace("PL/BindVessel 3: ApplyPlayerPreset returned " + presetOk)
    
    myEchoName = echoName
    self.GetActorBase().SetName(myEchoName)
    self.SetDisplayName(myEchoName)
    
    if myVesselSex == 0
        myVesselVoice = Game.GetForm(0x00013577) as VoiceType
    else
        myVesselVoice = Game.GetForm(0x00013543) as VoiceType
    endif
    self.GetActorBase().SetVoiceType(myVesselVoice)
    
    ; wake him — 3D gets built exactly once, with the right body
    self.Enable()
    self.QueueNiNodeUpdate()
    
    ; the gate finally means something: there IS no 3D till the enable lands
    int safety3D = 100
    while !self.Is3DLoaded() && safety3D > 0
        safety3D -= 1
        Wait(0.1)
    endWhile
    Debug.Trace("PL/BindVessel 4: 3D built after " + (100 - safety3D) + " ticks")
    
    if mySlotName != ""
        StageSlotForLoad(SlotIndex, mySlotName)
        Debug.Trace("PL/BindVessel 5: staged, calling LoadCharacter")
        
        Bool bOk = CharGen.LoadCharacter(self, myVesselRace, mySlotName)
        Int iSafety = 5
        while !bOk && iSafety > 0
            iSafety -= 1
            Wait(0.5)
            bOk = CharGen.LoadCharacter(self, myVesselRace, mySlotName)
        endWhile
        Debug.Trace("PL/BindVessel 6: LoadCharacter ok=" + bOk)
        
        UnstageSlotAfterLoad(SlotIndex, mySlotName)
        if !bOk
            Debug.Notification("Project Legacy: Face load failed for " + mySlotName)
        else
            ActorBase pBase = Game.GetPlayer().GetActorBase()
            ActorBase vBase = self.GetActorBase()
            vBase.SetSkin(pBase.GetSkin())
            vBase.SetFaceTextureSet(pBase.GetFaceTextureSet())
        EndIf
    EndIf
    
    self.UpdateWeight(0.0)
    Debug.Trace("PL/BindVessel 7: UpdateWeight done, exiting")
EndFunction

Function SummonVessel(Actor targetActor, ObjectReference pedestal)
    Debug.Trace("PL/Vessel: SummonVessel entered, SlotIndex = " + SlotIndex + ", echo = " + myEchoName)
    SetActorBaseSex(self, myVesselSex)
    Debug.Trace("PL/Vessel: SetActorBaseSex done, applying preset")
    bool presetOk = ApplyPlayerPreset(SlotIndex)
    Debug.Trace("PL/Vessel: ApplyPlayerPreset returned " + presetOk)
    
    if self.IsDisabled()
        Debug.Trace("PL/Vessel: was disabled, enabling")
        self.Enable()
    EndIf
    
    self.SetRestrained(false)
    self.BlockActivation(false)
    
    HomeStation = pedestal
    
    if PotentialFollowerFaction
        self.AddToFaction(PotentialFollowerFaction)
        self.SetRelationshipRank(targetActor, 3)
        Debug.Trace("PL/Vessel: follower faction added")
    else
        Debug.Trace("PL/Vessel: WARNING — PotentialFollowerFaction is None")
    endif
    
    self.EnableAI(true)
    self.EvaluatePackage()
    Debug.Trace("PL/Vessel: AI enabled, package evaluated")
    
    ; FF lesson: VisualEffect swirl art never expires on actors — use
    ; EffectShader versions, finite plays actually end on their own
    if PL_BlindingLightGold
        PL_BlindingLightGold.Play(self, 5.0)
    endif
    if PL_WarpTargetFX
        PL_WarpTargetFX.Play(self, 8.0)
    endif
    
    self.SetDisplayName(myEchoName)
    Debug.Trace("PL/Vessel: SummonVessel complete")
EndFunction

Function DismissVessel()
    if HomeStation
        self.MoveTo(HomeStation)
    endif
    
    self.SetRestrained(true)
    self.BlockActivation(true)
    self.EnableAI(false)
EndFunction

Function CleanseVessel()
    self.Disable()
    self.RemoveAllItems(None, true, true)
    mySlotName = ""
    myVesselRace = None
    myVesselVoice = None
    myVesselSex = 0
    myEchoName = ""
    self.GetActorBase().SetName("")
    self.SetDisplayName("")
    HomeStation = None
EndFunction

Function CopyGearFrom(Actor source)
    if !source
        return
    endif
    
    Debug.Trace("PL/Gear 1: entered, clearing default outfit")
    ClearDefaultOutfit(self)
    Debug.Trace("PL/Gear 2: outfit cleared, stripping items")
    self.RemoveAllItems(None, true, true)
    
    int h = 0x00000001
    while h > 0
        Form worn = source.GetWornForm(h)
        if worn != None
            Debug.Trace("PL/Gear 3: worn slot " + h + " = " + worn.GetName())
            self.AddItem(worn)
            self.EquipItemEx(worn, 0, true)
        endif
        h = Math.LeftShift(h, 1)
    endWhile
    Debug.Trace("PL/Gear 4: worn loop done")
    
    Form right = source.GetEquippedObject(1)
    Form left = source.GetEquippedObject(0)
    if right != None
        Debug.Trace("PL/Gear 5: right hand = " + right.GetName())
        self.AddItem(right)
        self.EquipItemEx(right, 1, true)
    endif
    if left != None && left != right
        Debug.Trace("PL/Gear 6: left hand = " + left.GetName())
        self.AddItem(left)
        self.EquipItemEx(left, 2, true)
    endif
    Debug.Trace("PL/Gear 7: hands done, calling ApplyPlayerGear")
    
    ApplyPlayerGear(SlotIndex)
    Debug.Trace("PL/Gear 8: ApplyPlayerGear returned")
EndFunction