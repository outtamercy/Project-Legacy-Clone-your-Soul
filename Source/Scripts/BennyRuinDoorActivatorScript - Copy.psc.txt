Scriptname BennyRuinDoorActivatorScript extends ObjectReference

ObjectReference Property aaBennyRuinLockedDoorRef Auto
ObjectReference Property aaBennyDoorPoweredLightRef Auto
ObjectReference Property aaBennyDoorPoweredSoulGemRef Auto
ObjectReference Property aaBennyDoorPoweredLightObj Auto
Message Property aaBennyRuinDoorActivatorMessage Auto
Message Property aaBennyRuinNoSoulGemMessage Auto
MiscObject Property SoulGemGrandFilled Auto
Actor Property PlayerRef Auto

Event OnLoad()
    ; Open the button cover when the cell is loaded
    Utility.Wait(0.5) ; Small delay to ensure the object is fully loaded
    Self.PlayAnimation("Open")
EndEvent

Event OnActivate(ObjectReference akActionRef)
    If PlayerRef.GetItemCount(SoulGemGrandFilled) > 0
        Int useGem = aaBennyRuinDoorActivatorMessage.Show()
        If useGem == 0 ; Player chose to open the door
            PlayerRef.RemoveItem(SoulGemGrandFilled, 1, True)
            aaBennyDoorPoweredLightRef.Enable(True)
            aaBennyDoorPoweredLightObj.Enable(True)
            aaBennyDoorPoweredSoulGemRef.Enable(True)
            aaBennyRuinLockedDoorRef.Activate(Self)
        EndIf
    Else
        aaBennyRuinNoSoulGemMessage.Show()
    EndIf
EndEvent