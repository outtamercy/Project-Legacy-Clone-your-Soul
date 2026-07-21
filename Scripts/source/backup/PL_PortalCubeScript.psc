Scriptname PL_PortalCubeScript extends ObjectReference

Import Utility
Import Game

Actor Property PlayerRef Auto
ObjectReference Property PL_ShelterMarker Auto

VisualEffect Property PL_ValorFX Auto
VisualEffect Property PL_WarpTargetFX Auto
ImageSpaceModifier Property PL_FadeToWhite Auto
ImageSpaceModifier Property PL_FadeToWhiteHoldImod Auto
ImageSpaceModifier Property PL_FadeToWhiteBackImod Auto

Event OnEquipped(Actor akActor)
    if akActor != PlayerRef
        return
    endif

    if !PL_ShelterMarker
        Debug.Notification("Project Legacy: Shelter marker missing!")
        return
    endif

    Debug.Notification("Entering the Hall...")

    ; lock down for the pretty lights
    DisablePlayerControls(abMovement = false, abFighting = true, abCamSwitch = true, abLooking = false, abSneaking = true, abMenu = true, abActivate = true, abJournalTabs = false)
    ForceThirdPerson()
    SetHudCartMode()
    Wait(0.25)

    PL_ValorFX.Play(PlayerRef, 3)
    Wait(1.0)

    PL_FadeToWhite.Apply()
    PL_WarpTargetFX.Play(PlayerRef, 8)
    Wait(0.5)

    ; ghost out
    PlayerRef.SetAlpha(0.01, true)
    Wait(2.0)

    ; snap to shelter
    PlayerRef.MoveTo(PL_ShelterMarker)
    Wait(0.01)

    ; hold white while cell loads, then fade back
    PL_FadeToWhite.PopTo(PL_FadeToWhiteHoldImod)
    Wait(0.1)
    PL_FadeToWhiteHoldImod.PopTo(PL_FadeToWhiteBackImod)

    ; restore
    PlayerRef.SetAlpha(1.0, true)
    Wait(2.0)

    SetHudCartMode(false)
    EnablePlayerControls()
EndEvent