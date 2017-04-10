{-# LANGUAGE DeriveFoldable    #-}
{-# LANGUAGE DeriveFunctor     #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE TypeFamilies      #-}

module Empire.API.Data.Port where

import           Data.Binary                 (Binary)
import           Prologue                    hiding (TypeRep)

import           Data.Aeson.Types            (FromJSON, ToJSON)
import           Data.Map                    (Map)
import           Empire.API.Data.LabeledTree (LabeledTree)
import           Empire.API.Data.PortDefault (PortDefault)
import           Empire.API.Data.TypeRep     (TypeRep)

data InPortIndex = Self | Arg Int                             deriving (Show, Eq, Ord, NFData, Generic)
data InPorts s   = InPorts { _self :: Maybe s, _args :: [s] } deriving (Default, Eq, Foldable, Functor, Generic, NFData, Show, Traversable)
type InPort      = [InPortIndex]
makeLenses ''InPorts

data    OutPortIndex  = Projection Int deriving (Show, Eq, Ord, NFData, Generic)
newtype OutPorts s    = OutPorts [s]   deriving (Default, Eq, Foldable, Functor, Generic, NFData, Show, Traversable)
type    OutPort       = [OutPortIndex]
makeWrapped ''OutPorts

instance Default (OutPorts s) where
    def = OutPorts def

instance Default (InPorts s) where
    def = InPorts def def

type InPortTree  a = LabeledTree InPorts  a
type OutPortTree a = LabeledTree OutPorts a

instance Binary   InPortIndex
instance ToJSON   InPortIndex
instance FromJSON InPortIndex
instance Binary   s => Binary   (InPorts s)
instance ToJSON   s => ToJSON   (InPorts s)
instance FromJSON s => FromJSON (InPorts s)

instance Binary   OutPortIndex
instance ToJSON   OutPortIndex
instance FromJSON OutPortIndex
instance Binary   s => Binary   (OutPorts s)
instance ToJSON   s => ToJSON   (OutPorts s)
instance FromJSON s => FromJSON (OutPorts s)

type instance Index   (InPorts s) = InPortIndex
type instance IxValue (InPorts s) = s
instance Ixed (InPorts s) where
    ix Self    = self . _Just
    ix (Arg i) = args . ix i

type instance Index   (OutPorts s) = OutPortIndex
type instance IxValue (OutPorts s) = s
instance Ixed (OutPorts s) where
    ix (Projection i) = wrapped . ix i


data PortId = InPortId InPort | OutPortId OutPort deriving (Generic, Show, Eq, Ord, NFData)
makePrisms ''PortId

data PortState = NotConnected | Connected | WithDefault PortDefault deriving (Show, Eq, Generic, NFData)

data Port = Port { _portId     :: PortId
                 , _name       :: String
                 , _valueType  :: TypeRep
                 , _state      :: PortState
                 } deriving (Show, Eq, Generic, NFData)

makeLenses ''Port
makePrisms ''PortState
instance Binary PortId
instance Binary Port
instance Binary PortState

isInPort :: PortId -> Bool
isInPort (InPortId _) = True
isInPort _            = False

isOutPort :: PortId -> Bool
isOutPort (OutPortId _) = True
isOutPort _             = False

isSelf :: PortId -> Bool
isSelf (InPortId (Self:_)) = True
isSelf _                   = False

isInAll :: PortId -> Bool
isInAll (InPortId []) = True
isInAll _             = False

isArg :: PortId -> Bool
isArg (InPortId (Arg _:_)) = True
isArg _                    = False

isOutAll :: PortId -> Bool
isOutAll (OutPortId []) = True
isOutAll _              = False

isProjection :: PortId -> Bool
isProjection (OutPortId (Projection _:_)) = True
isProjection _                            = False

getPortNumber :: PortId -> Int
getPortNumber (InPortId  (Arg i:_))        = i
getPortNumber (OutPortId (Projection i:_)) = i
getPortNumber _                            = 0
