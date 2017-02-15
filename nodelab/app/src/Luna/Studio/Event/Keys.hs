module Luna.Studio.Event.Keys where

import           Luna.Studio.Prelude

import           React.Flux          (KeyboardEvent (KeyboardEvent))


backspace, tab, enter, esc, leftArrow, upArrow, rightArrow, downArrow, del :: Int
backspace = 8
tab   = 9
enter = 13
esc   = 27
leftArrow  = 37
upArrow    = 38
rightArrow = 39
downArrow  = 40
del   = 46
zero  = 48

zero, a, h, y, z, plus, minus :: Int
a = 65
h = 72
y = 89
z = 90
plus  = 187
minus = 189

withoutMods :: KeyboardEvent -> Int -> Bool
withoutMods (KeyboardEvent False _ False _ _ keyCode _ _ False _ False _) key = keyCode == key
withoutMods _ _                                                               = False

withCtrl :: KeyboardEvent -> Int -> Bool
withCtrl (KeyboardEvent False _ True  _ _ keyCode _ _ _    _ False _) key = keyCode == key
withCtrl (KeyboardEvent False _ False _ _ keyCode _ _ True _ False _) key = keyCode == key
withCtrl _ _                                                              = False

withAlt :: KeyboardEvent -> Int -> Bool
withAlt (KeyboardEvent True _ False _ _ keyCode _ _ False _ False _) key = keyCode == key
withAlt _ _                                                              = False

withShift :: KeyboardEvent -> Int -> Bool
withShift (KeyboardEvent False _ False _ _ keyCode _ _ False _ True _) key = keyCode == key
withShift _ _                                                              = False

withCtrlAlt :: KeyboardEvent -> Int -> Bool
withCtrlAlt (KeyboardEvent True _ True  _ _ keyCode _ _ _    _ False _) key = keyCode == key
withCtrlAlt (KeyboardEvent True _ False _ _ keyCode _ _ True _ False _) key = keyCode == key
withCtrlAlt _ _                                                             = False

withCtrlShift :: KeyboardEvent -> Int -> Bool
withCtrlShift (KeyboardEvent False _ True  _ _ keyCode _ _ _    _ True _) key = keyCode == key
withCtrlShift (KeyboardEvent False _ False _ _ keyCode _ _ True _ True _) key = keyCode == key
withCtrlShift _ _                                                             = False

withAltShift :: KeyboardEvent -> Int -> Bool
withAltShift (KeyboardEvent True _ False _ _ keyCode _ _ False _ True _) key = keyCode == key
withAltShift _ _                                                             = False

withCtrlAltShift :: KeyboardEvent -> Int -> Bool
withCtrlAltShift (KeyboardEvent True _ True  _ _ keyCode _ _ _    _ False _) key = keyCode == key
withCtrlAltShift (KeyboardEvent True _ False _ _ keyCode _ _ True _ False _) key = keyCode == key
withCtrlAltShift _ _                                                             = False
