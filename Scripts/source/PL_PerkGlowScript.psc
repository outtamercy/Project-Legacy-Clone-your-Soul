Scriptname PL_PerkGlowScript extends ObjectReference

String Property StartNode Auto
ObjectReference Property Target Auto

Event OnLoad()
    if Target && StartNode
        self.MoveToNode(Target, StartNode)
        self.SplineTranslateToRef(Target, 500.0, 200.0, 10.0)
    endif
EndEvent