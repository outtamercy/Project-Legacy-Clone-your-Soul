Scriptname BennyShelterWealthScript extends ObjectReference

MiscObject Property Gold001 Auto
ObjectReference Property aaBennyShelterGoldStrongboxRef Auto
ObjectReference Property aaBennyShelterWealthMarker01 Auto
ObjectReference Property aaBennyShelterWealthMarker02 Auto
ObjectReference Property aaBennyShelterWealthMarker03 Auto
ObjectReference Property aaBennyShelterWealthMarker04 Auto

Event OnClose(ObjectReference akContainer)
    int goldAmount = aaBennyShelterGoldStrongboxRef.GetItemCount(Gold001)
    If goldAmount > 3000
        aaBennyShelterWealthMarker01.Enable()
    Else 
        aaBennyShelterWealthMarker01.Disable()
    EndIf

    If goldAmount > 5000
        aaBennyShelterWealthMarker02.Enable()
    Else
        aaBennyShelterWealthMarker02.Disable()
    EndIf

    If goldAmount > 10000
        aaBennyShelterWealthMarker03.Enable()
    Else
        aaBennyShelterWealthMarker03.Disable()
    EndIf

    If goldAmount > 20000
        aaBennyShelterWealthMarker04.Enable()
    Else
        aaBennyShelterWealthMarker04.Disable()
    EndIf
EndEvent