Scriptname BennyShelterWaterValveScript extends ObjectReference

; Swap this in the CK to any vanilla potion, ingredient, or food (like Ale or Wine)
Potion Property RewardItem Auto

Event OnActivate(ObjectReference akActionRef)
    If akActionRef == Game.GetPlayer()
        akActionRef.AddItem(RewardItem, 1)
        Debug.Notification("You take a refreshing drink.")
    EndIf
EndEvent