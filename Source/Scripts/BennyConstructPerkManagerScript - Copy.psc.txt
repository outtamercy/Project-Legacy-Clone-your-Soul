Scriptname BennyConstructPerkManagerScript extends ActiveMagicEffect

Perk Property aaBennyIncreaseSummons01 Auto
Perk Property aaBennyIncreaseSummons02 Auto
Perk Property aaBennyIncreaseSummons03 Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    If !akCaster.HasPerk(aaBennyIncreaseSummons01)
        akCaster.AddPerk(aaBennyIncreaseSummons01)
    ElseIf !akCaster.HasPerk(aaBennyIncreaseSummons02)
        akCaster.AddPerk(aaBennyIncreaseSummons02)
    ElseIf !akCaster.HasPerk(aaBennyIncreaseSummons03)
        akCaster.AddPerk(aaBennyIncreaseSummons03)
    EndIf
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
    If akCaster.HasPerk(aaBennyIncreaseSummons03)
        akCaster.RemovePerk(aaBennyIncreaseSummons03)
    ElseIf akCaster.HasPerk(aaBennyIncreaseSummons02)
        akCaster.RemovePerk(aaBennyIncreaseSummons02)
    ElseIf akCaster.HasPerk(aaBennyIncreaseSummons01)
        akCaster.RemovePerk(aaBennyIncreaseSummons01)
    EndIf
EndEvent