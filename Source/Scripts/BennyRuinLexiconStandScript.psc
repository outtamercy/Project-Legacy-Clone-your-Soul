Scriptname BennyRuinLexiconStandScript extends ObjectReference

ObjectReference Property aaBennyRuinLexiconStandFullRef Auto
ObjectReference Property aaBennyRuinLexiconStandBlankRef Auto
ObjectReference Property aaBennyRuinLexiconLightRef Auto
Actor Property PlayerRef Auto

Event OnLoad()
    ; Set the lexicon down when the cell is loaded
    Utility.Wait(0.5) ; Small delay to ensure the object is fully loaded
    Self.PlayAnimation("SetDown")
EndEvent

Event OnActivate(ObjectReference akActionRef)
    Self.PlayAnimation("PickUp")
    aaBennyRuinLexiconStandBlankRef.Enable()
    Utility.Wait(0.5)
    aaBennyRuinLexiconLightRef.Disable()
    aaBennyRuinLexiconStandFullRef.Disable()
    ; nothing to add — portal cube is MCM-only now
EndEvent