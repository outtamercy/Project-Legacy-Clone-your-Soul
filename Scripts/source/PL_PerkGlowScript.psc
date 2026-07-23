Scriptname PL_PerkGlowScript extends ObjectReference

String Property StartNode Auto
ObjectReference Property Target Auto        ; who to start on (the player)
ObjectReference Property FlyTo Auto         ; where to fly to (the station)

Event OnLoad()
    if Target && StartNode && FlyTo
        self.MoveToNode(Target, StartNode)
        Utility.Wait(Utility.RandomFloat(0.0, 1.0))
        self.SplineTranslateToRef(FlyTo, 500.0, 200.0, 10.0)
        Utility.Wait(4.0)
        self.Delete()
    endif
EndEvent