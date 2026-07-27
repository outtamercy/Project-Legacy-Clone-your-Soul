Scriptname BennySaunaControlScript extends ObjectReference

ObjectReference Property aaBennyShelterSaunaMarkerRef Auto

Auto State SaunaDisabled
    Event OnActivate(ObjectReference akActionRef)
        aaBennyShelterSaunaMarkerRef.Enable(True)
        GoToState("SaunaEnabled")
    EndEvent
EndState

State SaunaEnabled
    Event OnActivate(ObjectReference akActionRef)
            aaBennyShelterSaunaMarkerRef.Disable(True)
            GoToState("SaunaDisabled")
    EndEvent
EndState