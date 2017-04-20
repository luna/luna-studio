{-# OPTIONS_GHC -fno-warn-orphans #-}
module Common.Prelude.Instances where

import           Data.Aeson
import           Data.Convert               (Convertible (convert))
import           Data.Default               (Default (def))
import           Data.Hashable              (Hashable)
import           Data.HashMap.Strict        (HashMap)
import qualified Data.HashMap.Strict        as HashMap
import           Data.JSString              (JSString)
import qualified Data.JSString              as JSString
import           Development.Placeholders
import           Empire.API.JSONInstances   ()
import           Prologue
import           React.Flux
import           React.Flux.Store           (ReactStoreRef)

import           Empire.API.Data.Breadcrumb (Breadcrumb, BreadcrumbItem)
import           Empire.API.Data.NodeLoc    (NodeLoc, NodePath)
import           Empire.API.Data.Port       (InPortIndex, OutPortIndex)
import           Empire.API.Data.PortRef    (AnyPortRef, InPortRef, OutPortRef)

-- ======= React.Flux ==========================================================

instance Eq (ReactStore a) where _ == _ = True
instance NFData a => NFData (ReactStoreRef a)
instance NFData a => NFData (ReactStore a)

instance ToJSON   MouseEvent where
    toJSON _ = toJSON "(MouseEvent)"
instance FromJSON MouseEvent where
    parseJSON = $notImplemented

instance Read KeyboardEvent where
    readPrec = error "Read KeyboardEvent"

instance ToJSON   KeyboardEvent where
    toJSON _ = toJSON "(KeyboardEvent)"
instance FromJSON KeyboardEvent where
    parseJSON = $notImplemented

instance ToJSON   WheelEvent where
    toJSON _ = toJSON "(WheelEvent)"
instance FromJSON WheelEvent where
    parseJSON = $notImplemented

instance ToJSON   TouchEvent where
    toJSON _ = toJSON "(TouchEvent)"
instance FromJSON TouchEvent where
    parseJSON = $notImplemented

instance ToJSON   Event where
    toJSON _ = toJSON "(Event)"
instance FromJSON Event where
    parseJSON = $notImplemented

-- ======= GHCJS ===============================================================

instance Default JSString where
    def = JSString.empty

instance Convertible Text JSString where
    convert = JSString.pack . convert

instance Convertible JSString Text where
    convert = convert . JSString.unpack

instance Convertible String JSString where
    convert = JSString.pack

instance Convertible JSString String where
    convert = JSString.unpack

instance (ToJSON k, ToJSON v) => ToJSON (HashMap k v) where
    toJSON = toJSON . HashMap.toList
    {-# INLINE toJSON #-}

instance (Eq k, FromJSON k, FromJSON v, Hashable k) => FromJSON (HashMap k v) where
    parseJSON = fmap HashMap.fromList . parseJSON
    {-# INLINE parseJSON #-}
-- ======= Data.HashMap ========================================================

instance Default (HashMap a b) where def = HashMap.empty
instance Hashable a => Hashable (Breadcrumb a)
instance Hashable AnyPortRef
instance Hashable BreadcrumbItem
instance Hashable InPortIndex
instance Hashable InPortRef
instance Hashable NodeLoc
instance Hashable NodePath
instance Hashable OutPortIndex
instance Hashable OutPortRef