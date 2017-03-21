module Luna.Studio.Action.Node.Snap
    ( snap
    , snapCoord
    ) where

import           Data.Position                     (Position, x, y)
import           Luna.Studio.Prelude
import           Luna.Studio.React.Model.Constants (gridSize)

snapCoord :: Double -> Double
snapCoord p = (* gridSize) . fromIntegral $ (round $ p / gridSize :: Integer)

snap :: Position -> Position
snap = (x %~ snapCoord) . (y %~ snapCoord)
