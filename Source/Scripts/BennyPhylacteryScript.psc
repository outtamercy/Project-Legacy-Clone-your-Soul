Scriptname BennyPhylacteryScript extends ObjectReference

; Keep ONLY the machine reference for animations
ObjectReference Property aaBennySoulBindingStandRef Auto

Event OnActivate(ObjectReference akActionRef)
    ; The quest/message bloat is gone, but we preserve the animation keys for reference
    ; aaBennySoulBindingStandRef.PlayAnimation("Open")
    ; aaBennySoulBindingStandRef.PlayAnimation("StartClose")
    ; aaBennySoulBindingStandRef.PlayAnimation("PickUp")
    ; aaBennySoulBindingStandRef.PlayAnimation("SetDown")
EndEvent