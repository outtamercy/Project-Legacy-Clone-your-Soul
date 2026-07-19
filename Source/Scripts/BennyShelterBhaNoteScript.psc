Scriptname BennyShelterBhaNoteScript extends ObjectReference

GlobalVariable Property aaBennyBhaNoteRead Auto

Event OnActivate(ObjectReference akActionRef)
    aaBennyBhaNoteRead.SetValue(1)
    Debug.Trace("[Benny'sShelter] Player has read Bha's note.")
EndEvent