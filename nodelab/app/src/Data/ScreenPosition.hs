{-# LANGUAGE TypeFamilies #-}
module Data.ScreenPosition
    ( module Data.ScreenPosition
    , module X
    )
where

import           Data.Aeson          (FromJSON, ToJSON)
import           Data.Vector         as X
import           Luna.Studio.Prelude
-----------------------------
-- === ScreenPosition === ---
-----------------------------

-- === Definition === --

newtype ScreenPosition = ScreenPosition { fromScreenPosition :: Vector2 Double } deriving (Eq, Show, Generic, Default, NFData, Num)
makeWrapped ''ScreenPosition


-- === Instances === --

type instance VectorOf ScreenPosition = Vector2 Double

instance Dim1      ScreenPosition
instance Dim2      ScreenPosition
instance FromJSON  ScreenPosition
instance IsVector  ScreenPosition
instance ToJSON    ScreenPosition

instance IsList ScreenPosition where
    type Item ScreenPosition = Double
    fromList l = ScreenPosition (fromList l)
    toList   p = [p ^. x, p ^. y]
