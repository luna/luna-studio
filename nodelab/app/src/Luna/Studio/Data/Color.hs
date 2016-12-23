{-# LANGUAGE OverloadedStrings #-}
module Luna.Studio.Data.Color
    ( colorPort
    , vtToColor
    , Color (..)
    , toJSString
    ) where

import           Data.Aeson                (FromJSON, ToJSON)
import           Data.Hashable             (hash)
import           Luna.Studio.Prelude

import           Empire.API.Data.Port      (Port)
import qualified Empire.API.Data.Port      as Port
import           Empire.API.Data.TypeRep   (TypeRep (..))
import           Empire.API.Data.ValueType (ValueType (..))



newtype Color = Color { fromColor :: Int }
              deriving (Eq, Generic, Ord, Show)

instance FromJSON Color
instance ToJSON Color



data HSL a = HSL { _h :: a
                 , _s :: a
                 , _l :: a
                 } deriving (Eq, Ord, Show)

makeLenses ''HSL

toHsl :: Color -> HSL Float
toHsl (Color 0) = HSL 0.0 0.0 0.5
toHsl (Color i) = HSL (hue * 2.0 * pi) 0.6 0.5
    where
        hue = start + delta * (fromIntegral i)
        start = 90.6 / (2 * pi)
        steps = 16.0
        delta = 1.0 / steps

toJSString :: Color -> JSString
toJSString = hslToJSString . toHsl

hslToJSString :: (Fractional a, Show a) => HSL a -> JSString
hslToJSString hsl = fromString $ "hsl(" <> show ((hsl ^. h) * 360.0) <> ","
                                     <> show ((hsl ^. s) * 100.0) <> "%,"
                                     <> show ((hsl ^. l) * 100.0) <> "%)"

hashMany :: [TypeRep] -> Int
hashMany as = sum $ zipWith (*) powers (tpRepToColor <$> as) where
    nums   = [0..] :: [Integer]
    powers = (37 ^) <$> nums

ensureRange :: Integral a => a -> a
ensureRange n = (n `mod` 8) + 1

tpRepToColor :: TypeRep -> Int
tpRepToColor (TCons tn as) = ensureRange $ case tn of
     "Int"        -> 0
     "Bool"       -> 1
     "Double"     -> 2
     "String"     -> 3
     "List"       -> 5 + hashMany as
     _            -> hash tn + hashMany as
tpRepToColor (TLam as out) = ensureRange . hashMany $ out : as
tpRepToColor (TVar _n) = 9
tpRepToColor _ = 0

vtToColor :: ValueType -> Color
vtToColor (TypeIdent t) = Color $ tpRepToColor t
vtToColor _ = Color 0

colorPort :: Port -> Color
colorPort port = vtToColor $ port ^. Port.valueType
