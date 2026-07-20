Scriptname PL_VesselActor extends Actor

Import Utility

int Property SlotIndex Auto
VisualEffect Property PL_ValorFX Auto
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

Function BindVessel(String slotName, Race vesselRace, int vesselSex, String echoName)
    mySlotName = slotName
    myVesselRace = vesselRace
    myVesselSex = vesselSex
    
    ; Align native underlying gender cache fields via explicit assignments
    SetActorBaseSex(self, myVesselSex)
    ApplyPlayerPreset(SlotIndex)
    
    if myVesselRace && self.GetRace() != myVesselRace
        self.SetRace(myVesselRace)
    endif
    
    myEchoName = echoName
    self.GetActorBase().SetName(myEchoName)
    self.SetDisplayName(myEchoName)
    
    if myVesselSex == 0
        myVesselVoice = Game.GetForm(0x00013577) as VoiceType
    else
        myVesselVoice = Game.GetForm(0x00013543) as VoiceType
    endif
    self.GetActorBase().SetVoiceType(myVesselVoice)
    
    if mySlotName != ""
        StageSlotForLoad(SlotIndex, mySlotName)
        
        Bool bOk = CharGen.LoadCharacter(self, myVesselRace, mySlotName)
        Int iSafety = 5
        while !bOk && iSafety > 0
            iSafety -= 1
            Wait(0.5)
            bOk = CharGen.LoadCharacter(self, myVesselRace, mySlotName)
        endWhile
        
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
EndFunction

Function SummonVessel(Actor targetActor, ObjectReference pedestal)
    SetActorBaseSex(self, myVesselSex)
    ApplyPlayerPreset(SlotIndex)
    
    if self.IsDisabled()
        self.Enable()
    EndIf
    
    self.SetRestrained(false)
    self.BlockActivation(false)
    
    HomeStation = pedestal
    
    if PotentialFollowerFaction
        self.AddToFaction(PotentialFollowerFaction)
        self.SetRelationshipRank(targetActor, 3)
    endif
    
    self.EnableAI(true)
    self.EvaluatePackage()
    
    if PL_ValorFX
        PL_ValorFX.Play(self, 5.0)
    endif
    if PL_WarpTargetFX
        PL_WarpTargetFX.Play(self, 8.0)
    endif
    
    self.SetDisplayName(myEchoName)
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
    
    ClearDefaultOutfit(self)
    self.RemoveAllItems(None, true, true)
    
    int h = 0x00000001
    while h > 0
        Form worn = source.GetWornForm(h)
        if worn != None
            self.AddItem(worn)
            self.EquipItemEx(worn, 0, true)
        endif
        h = Math.LeftShift(h, 1)
    endWhile
    
    Form right = source.GetEquippedObject(1)
    Form left = source.GetEquippedObject(0)
    if right != None
        self.AddItem(right)
        self.EquipItemEx(right, 1, true)
    endif
    if left != None && left != right
        self.AddItem(left)
        self.EquipItemEx(left, 2, true)
    endif
    
    ApplyPlayerGear(SlotIndex)
EndFunction