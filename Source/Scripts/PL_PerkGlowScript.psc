Scriptname PL_PerkGlowScript extends ObjectReference

String Property StartNode Auto
ObjectReference Property Target Auto        ; who to start on (the player)
ObjectReference Property FlyTo Auto         ; where to fly to (the station)

Event OnLoad()
    if Target && StartNode && FlyTo
        ; backstop: a blocked spline must not make this ref immortal
        RegisterForSingleUpdate(8.0)

        int safety = 50
        while !self.Is3DLoaded() && safety > 0
            safety -= 1
            Utility.Wait(0.1)
        endWhile
        self.SetScale(1.6)  ; meridia glow mesh is small — read bigger
        self.MoveToNode(Target, StartNode)
        ; linger visibly on the body before flying — 0-1s was a subliminal blip
        Utility.Wait(Utility.RandomFloat(1.2, 2.5))
        ; slower flight so the eye can track it: 500 u/s was ~0.25s of travel
        self.SplineTranslateToRef(FlyTo, 180.0, 200.0, 10.0)
        Utility.Wait(2.0)
        self.Delete()
    endif
EndEvent

Event OnUpdate()
    self.Delete()
EndEvent
