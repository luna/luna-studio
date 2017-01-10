module Luna.Studio.Action.Camera.Screen
     ( getScreenCenter
     , getScreenCenterFromSize
     , getScreenSize
     , translateToWorkspace
     ) where

import           Data.Matrix                           (getElem, multStd2)
import qualified Data.Matrix                           as Matrix
import           Luna.Studio.Action.Command            (Command)
import           Luna.Studio.Data.CameraTransformation (screenToLogical)
import           Luna.Studio.Data.Vector               (Position (Position), ScreenPosition, Size (Size), fromTuple, scalarProduct, vector,
                                                        x, y)
import           Luna.Studio.Prelude
import qualified Luna.Studio.React.Model.NodeEditor    as NodeEditor
import qualified Luna.Studio.React.Store               as Store
import           Luna.Studio.State.Global              (State)
import qualified Luna.Studio.State.Global              as Global

foreign import javascript safe "document.getElementById('Graph').offsetWidth"  screenWidth  :: IO Double
foreign import javascript safe "document.getElementById('Graph').offsetHeight" screenHeight :: IO Double

getScreenCenter :: Command State ScreenPosition
getScreenCenter = getScreenCenterFromSize <$> getScreenSize

getScreenCenterFromSize :: Size -> ScreenPosition
getScreenCenterFromSize = Position . flip scalarProduct 0.5 . view vector

getScreenSize :: Command State Size
getScreenSize = liftIO $ Size . fromTuple <$> ((,) <$> screenWidth <*> screenHeight)

translateToWorkspace :: ScreenPosition -> Command State (Position)
translateToWorkspace pos = do
    transformMatrix <- Global.withNodeEditor $ Store.use $ NodeEditor.screenTransform . screenToLogical
    let posMatrix      = Matrix.fromList 1 4 [ pos ^. x, pos ^. y, 1, 1]
        posInWorkspace = multStd2 posMatrix transformMatrix
    return $ Position $ fromTuple (getElem 1 1 posInWorkspace, getElem 1 2 posInWorkspace)
