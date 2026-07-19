Scriptname BennyAlternateDeathScript extends ReferenceAlias

ObjectReference Property aaBennySaltChamberActivatorRef Auto
ObjectReference Property aaBennyShelterInteriorMarker Auto
ObjectReference Property aaBennyPlayerLocationMarker Auto
ObjectReference Property aaBennySoulBindingStandRef Auto
ObjectReference Property aaBennyBackupKnapsackRef Auto
ObjectReference Property aaBennyTrackerMarkerRef Auto
ObjectReference Property aaBennyDeathKnapsackRef Auto
ObjectReference Property aaBennyShelterExitRef Auto

GlobalVariable Property aaBennySaltChamberRepaired Auto
GlobalVariable Property aaBennyExperienceLossPct Auto
GlobalVariable Property aaBennyGoldLossPct Auto

Message Property aaBennyRevivalNotificationMessage Auto
ImageSpaceModifier Property aaBennyFadeToBlackImod Auto
Spell Property aaBennyPDCarryWeightBuffSpell Auto
Quest Property aaBennyRetrieveBackpackQuest Auto
Potion Property aaBennyShelterEntryDevice Auto
MiscObject Property Gold001 Auto
ActorBase Property Player Auto
Armor Property aaBennyDeathRing Auto
Actor Property PlayerRef Auto

int lostGoldAmount
int lostExperienceAmount

Event OnEnterBleedout()
    ; Disable PC Controls and wait for bleedout animation to take effect
    Player.SetInvulnerable(True)
    Game.DisablePlayerControls(True, True, True, True, True, True, True)
    ; Stop the player from ragdolling
    ; PlayerRef.ForceRemoveRagdollFromWorld()
    ; Also prevent bleedout recovery and ensure player can't be re-downed
    PlayerRef.SetNoBleedoutRecovery(True)
    Utility.wait(2.0)
    ; Wait until player has stopped moving. This should cover ragdoll states from giants as well as shouts.
    ; Float currentX = PlayerRef.GetPositionX()
    ; Float currentY = PlayerRef.GetPositionY()
    ; Float currentZ = PlayerRef.GetPositionZ()
    ; Float lastX = 0.0
    ; Float lastY = 0.0
    ; Float lastZ = 0.0
    ; While (Math.Abs(currentX - lastX) > 3.0) || (Math.Abs(currentY - lastY) > 3.0) || (Math.Abs(currentZ - lastZ) > 3.0)
    ;     lastX = currentX
    ;     lastY = currentY
    ;     lastZ = currentZ
    ;     Utility.wait(0.5)
    ;     currentX = PlayerRef.GetPositionX()
    ;     currentY = PlayerRef.GetPositionY()
    ;     currentZ = PlayerRef.GetPositionZ()
    ;     Debug.trace("Waiting for player to stop moving... Current: (" + currentX + ", " + currentY + ", " + currentZ + ") vs Previous: (" + lastX + ", " + lastY + ", " + lastZ + ")")
    ; EndWhile
    ; Debug.trace("Player has stopped moving. Proceeding with alternate death sequence.")
    ; Fade screen to black while we work ...
    aaBennyFadeToBlackImod.Apply()
    ; Move pocket dimension exit marker to player location
    ; Might want to make this better in the future
    aaBennyPlayerLocationMarker.MoveTo(aaBennyTrackerMarkerRef)
    ; Move dropped items container to player location and make sure it's empty.
    ; Store any leftover contents in the backup container.
    aaBennyDeathKnapsackRef.RemoveAllItems(aaBennyBackupKnapsackRef)
    Utility.wait(0.3)
    aaBennyDeathKnapsackRef.MoveTo(PlayerRef)
    ; Return player to normal state before moving to shelter
    Utility.wait(2.0)
    PlayerRef.ResetHealthAndLimbs()
    ; Game.ForceFirstPerson()
    ; Calculate and remove gold and experience penalties
    int goldCount = PlayerRef.GetItemCount(Gold001)
    float currentExperience = Game.GetPlayerExperience()
    float expLossPercent = aaBennyExperienceLossPct.GetValue()
    If PlayerRef.IsEquipped(aaBennyDeathRing)
        expLossPercent = expLossPercent * 0.5 ; Halve experience loss if death ring is equipped
    EndIf
    float experienceLoss = currentExperience * expLossPercent
    If goldCount > 0
        int removeGold = (goldCount * aaBennyGoldLossPct.GetValue()) as int
        lostGoldAmount = removeGold
        PlayerRef.RemoveItem(Gold001, removeGold, True)
        aaBennyDeathKnapsackRef.AddItem(Gold001, removeGold)
    Else
        ; Double experience loss if there is no gold to pay
        lostGoldAmount = 0
        experienceLoss = currentExperience * (expLossPercent * 2)
    EndIf
    lostExperienceAmount = experienceLoss as int
    Game.SetPlayerExperience(currentExperience - experienceLoss)
    While PlayerRef.IsBleedingOut()
        Utility.wait(0.1)
    EndWhile
    ; Move player to shelter interior after short delay to ensure bleedout animation is finished.
    RegisterForSingleUpdate(3.0)
EndEvent

Event OnUpdate()
    ; Move player to shelter interior and do shelter setup animations
    PlayerRef.MoveTo(aaBennyShelterInteriorMarker)
    PlayerRef.RemoveItem(aaBennyShelterEntryDevice, 1, True)
    ; Game.ForceThirdPerson()
    If aaBennySaltChamberRepaired.GetValueInt() == 1
        aaBennySaltChamberActivatorRef.PlayAnimation("Open")
    EndIf
    aaBennyShelterExitRef.PlayAnimation("SetDown")
    aaBennySoulBindingStandRef.PlayAnimation("SetDown")
    Utility.wait(0.5)
    aaBennyShelterExitRef.PlayAnimation("Open")
    aaBennySoulBindingStandRef.PlayAnimation("Open")
    Player.SetInvulnerable(False)
    PlayerRef.AddSpell(aaBennyPDCarryWeightBuffSpell)
    Game.EnablePlayerControls(True, True, True, True, True, True, True)
    aaBennyFadeToBlackImod.Remove()
    ; Display notification message about lost gold and experience
    aaBennyRevivalNotificationMessage.Show(lostGoldAmount, lostExperienceAmount)
    ; Start quest to retrieve backpack
    aaBennyRetrieveBackpackQuest.Start()
    aaBennyRetrieveBackpackQuest.SetObjectiveDisplayed(0)
EndEvent