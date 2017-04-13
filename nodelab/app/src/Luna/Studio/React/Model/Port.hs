{-# LANGUAGE DeriveAnyClass #-}
module Luna.Studio.React.Model.Port
    ( module Luna.Studio.React.Model.Port
    , module X
    )
    where

import           Data.Aeson                  (ToJSON)
import           Data.Convert                (Convertible (convert))
import           Data.Position               (Position)
import           Empire.API.Data.LabeledTree (LabeledTree (LabeledTree))
import           Empire.API.Data.Port        as X hiding (InPort, OutPort, Port (..), name, portId, state, valueType)
import qualified Empire.API.Data.Port        as Empire
import           Empire.API.Data.PortDefault as X (PortDefault (..))
import           Empire.API.Data.PortRef     as X (AnyPortRef (InPortRef', OutPortRef'), InPortRef (InPortRef), OutPortRef (OutPortRef))
import           Empire.API.Data.TypeRep     (TypeRep (..))
import           Luna.Studio.Data.Color      (Color)
import qualified Luna.Studio.Data.Color      as Color
import           Luna.Studio.Prelude         hiding (set)


data Mode = Normal
          | Invisible
          | Highlighted
          | Moved Position
          | NameEdit
          deriving (Eq, Show, Typeable, Generic, NFData)

instance ToJSON Mode
instance Default Mode where
    def = Normal

data Port i = Port
        { _portId    :: i
        , _name      :: String
        , _valueType :: TypeRep
        , _state     :: PortState
        , _color     :: Color
        , _mode      :: Mode
        } deriving (Eq, Functor, Generic, NFData, Show, Typeable)

type InPort = Port InPortId
type OutPort = Port OutPortId
type AnyPort = Port AnyPortId
type EitherPort = Either InPort OutPort

makeLenses ''Port
instance ToJSON i => ToJSON (Port i)

isInMode :: Mode -> Port i -> Bool
isInMode m p = case (m, p ^. mode) of
    (Moved _, Moved _) -> True
    (m1, m2)           -> m1 == m2

isInNormalMode :: Port i -> Bool
isInNormalMode = isInMode Normal

isInvisible :: Port i -> Bool
isInvisible = isInMode Invisible

ensureVisibility :: Mode -> Mode
ensureVisibility Invisible = Normal
ensureVisibility m = m

isHighlighted :: Port i -> Bool
isHighlighted = isInMode Highlighted

isInMovedMode :: Port i -> Bool
isInMovedMode = isInMode (Moved def)

isInNameEditMode :: Port i -> Bool
isInNameEditMode = isInMode NameEdit

getPositionInSidebar :: Port i -> Maybe Position
getPositionInSidebar p = case p ^. mode of
    Moved pos -> Just pos
    _         -> Nothing

-- countOutPorts :: OutPortTree Port -> Int
-- countOutPorts (OutPortTree _ []) = 1
-- countOutPorts (OutPortTree _ ps) = sum $ map countOutPorts ps
--
outPortTreeLeafs :: OutPortTree (Port i) -> [Port i]
outPortTreeLeafs (LabeledTree (OutPorts []) p) = [p]
outPortTreeLeafs (LabeledTree (OutPorts ps) _) = concatMap outPortTreeLeafs ps

inPortTreeLeafs :: InPortTree (Port i) -> [Port i]
inPortTreeLeafs (LabeledTree (InPorts Nothing []) p) = [p]
inPortTreeLeafs (LabeledTree (InPorts mps     ps) _) = concatMap inPortTreeLeafs $ maybeToList mps <> ps

-- countArgPorts :: [AnyPortId] -> Int
-- countArgPorts = foldl (\acc pid -> acc + if isArg pid then 1 else 0) 0
--
-- countProjectionPorts :: [AnyPortId] -> Int
-- countProjectionPorts = foldl (\acc pid -> acc + if isProjection pid then 1 else 0) 0

instance Convertible InPort  AnyPort where convert = fmap InPortId'
instance Convertible OutPort AnyPort where convert = fmap OutPortId'

instance Convertible AnyPort EitherPort where
    convert (Port (InPortId'  i) n nt s c m) = Left $ Port i n nt s c m
    convert (Port (OutPortId' i) n nt s c m) = Right $ Port i n nt s c m

instance Convertible EitherPort AnyPort where
    convert (Left  port) = InPortId'  <$> port
    convert (Right port) = OutPortId' <$> port

instance Convertible (Empire.Port i) (Port i) where
    convert p = Port
        {- portId    -} (p ^. Empire.portId)
        {- name      -} (p ^. Empire.name)
        {- nodeType  -} (p ^. Empire.valueType)
        {- state     -} (p ^. Empire.state)
        {- color     -} (Color.fromType $ p ^. Empire.valueType)
        {- mode      -} Normal

instance Convertible (Port i) (Empire.Port i) where
    convert p = Empire.Port
        {- portId    -} (p ^. portId)
        {- name      -} (p ^. name)
        {- nodeType  -} (p ^. valueType)
        {- state     -} (p ^. state)
