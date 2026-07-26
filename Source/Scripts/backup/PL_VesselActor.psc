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

bool Function StageSlotForLoad(int slot, string slotName) Global Native
bool Function UnstageSlotAfterLoad(int slot, string slotName) Global Native
bool Function ClearDefaultOutfit(Actor target) Global Native
bool Function SetActorBaseSex(Actor target, int sex) Global Native

Event OnInit()
    self.Disable()
EndEvent

Function BindVessel(String slotName, Race vesselRace, VoiceType vesselVoice)
    mySlotName = slotName
    myVesselRace = vesselRace
    myVesselVoice = vesselVoice
    myVesselSex = Game.GetPlayer().GetActorBase().GetSex()
    
    SetActorBaseSex(self, myVesselSex)
    self.SetRace(myVesselRace)
    
    myEchoName = Game.GetPlayer().GetActorBase().GetName()
    self.GetActorBase().SetVoiceType(vesselVoice)
    self.SetDisplayName(myEchoName)
    
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
        EndIf
    EndIf
    
    self.UpdateWeight(0.0)
    self.QueueNiNodeUpdate()
EndFunction

Function SummonVessel(Actor targetActor, ObjectReference pedestal)
    self.SetRace(myVesselRace)
    SetActorBaseSex(self, myVesselSex)
    
    if self.IsDisabled()
        self.Enable()
    EndIf
    
    self.SetRestrained(false)
    self.BlockActivation(false)
    
    self.GetActorBase().SetInvulnerable(True)
    
    if PotentialFollowerFaction
        self.AddToFaction(PotentialFollowerFaction)
        self.SetRelationshipRank(targetActor, 3)
    endif
    
    self.EvaluatePackage()
    
    if PL_ValorFX
        PL_ValorFX.Play(self, 5.0)
    endif
    if PL_WarpTargetFX
        PL_WarpTargetFX.Play(self, 8.0)
    endif
    
    self.SetDisplayName(myEchoName)
    self.GetActorBase().SetInvulnerable(False)
EndFunction

Function DismissVessel()
    self.GetActorBase().SetInvulnerable(True)
    self.SetRestrained(true)
    self.BlockActivation(true)
EndFunction

Function CleanseVessel()
    self.Disable()
    self.RemoveAllItems(None, true, true)
    mySlotName = ""
    myVesselRace = None
    myVesselVoice = None
    myVesselSex = 0
    myEchoName = ""
    self.SetDisplayName("")
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
EndFunction