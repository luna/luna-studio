{-# OPTIONS_GHC -fno-warn-orphans #-}
module Luna.Studio.Action.Camera.Pan
     ( resetPan
     , stopPanDrag
     , panLeft
     , panRight
     , panUp
     , panDown
     , panCamera
     , startPanDrag
     , panDrag
     ) where

import           Data.Matrix                           (setElem)
import           Data.ScreenPosition                   (ScreenPosition, Vector2 (Vector2), vector)
import           Luna.Studio.Action.Camera.Modify      (modifyCamera)
import           Luna.Studio.Action.Command            (Command)
import           Luna.Studio.Data.CameraTransformation (logicalToScreen, screenToLogical)
import           Luna.Studio.Data.Matrix               (invertedTranslationMatrix, translationMatrix)
import           Luna.Studio.Prelude
import qualified Luna.Studio.React.Model.NodeEditor    as NodeEditor
import           Luna.Studio.State.Action              (Action (begin, continue, end, update), PanDrag (PanDrag), panDragAction)
import qualified Luna.Studio.State.Action              as Action
import           Luna.Studio.State.Global              (State, beginActionWithKey, continueActionWithKey, removeActionFromState,
                                                        updateActionWithKey)
import qualified Luna.Studio.State.Global              as Global


instance Action (Command State) PanDrag where
    begin    = beginActionWithKey    panDragAction
    continue = continueActionWithKey panDragAction
    update   = updateActionWithKey   panDragAction
    end _    = removeActionFromState panDragAction

panStep :: Double
panStep = 50

panCamera :: Vector2 Double -> Command State ()
panCamera delta = modifyCamera (translationMatrix delta) (invertedTranslationMatrix delta)

panLeft, panRight, panUp, panDown :: Command State ()
panLeft  = panCamera $ Vector2 (-panStep) 0
panRight = panCamera $ Vector2 panStep    0
panUp    = panCamera $ Vector2 0          (-panStep)
panDown  = panCamera $ Vector2 0          panStep

startPanDrag :: ScreenPosition -> Command State ()
startPanDrag pos = begin $ PanDrag pos

panDrag :: ScreenPosition -> PanDrag -> Command State ()
panDrag actPos state = do
    let prevPos = view Action.panDragPreviousPos state
        delta = actPos ^. vector - prevPos ^. vector
    update $ PanDrag actPos
    panCamera delta

resetPan :: Command State ()
resetPan = Global.modifyNodeEditor $ do
    NodeEditor.screenTransform . logicalToScreen %= (setElem 0 (4,1) . setElem 0 (4,2))
    NodeEditor.screenTransform . screenToLogical %= (setElem 0 (4,1) . setElem 0 (4,2))

stopPanDrag :: PanDrag -> Command State ()
stopPanDrag _ = removeActionFromState panDragAction
