{-# LANGUAGE Rank2Types #-}
module Luna.Studio.Event.Preprocessor.Batch (process) where

import           Data.Binary                            (Binary, decode)
import           Data.ByteString.Lazy.Char8             (ByteString)
import qualified Data.Map.Lazy                          as Map
import           Luna.Studio.Prelude                    hiding (cons)

import qualified Empire.API.Topic                       as Topic
import           Luna.Studio.Batch.Connector.Connection (ControlCode (ConnectionTakeover, Welcome), WebMessage (ControlMessage, WebMessage))
import           Luna.Studio.Event.Batch                as Batch
import           Luna.Studio.Event.Connection           as Connection
import qualified Luna.Studio.Event.Event                as Event


process :: Event.Event -> Maybe Event.Event
process (Event.Connection (Message msg)) = Just $ Event.Batch $ processMessage msg
process _                                = Nothing

handle :: forall a. (Binary a, Topic.MessageTopic a) => (a -> Batch.Event) -> (String, ByteString -> Batch.Event)
handle cons = (Topic.topic (undefined :: a), cons . decode)

handlers :: Map.Map String (ByteString -> Batch.Event)
handlers = Map.fromList [ handle NodeAdded
                        , handle AddNodeResponse
                        , handle NodesRemoved
                        , handle RemoveNodesResponse
                        , handle NodesConnected
                        , handle ConnectResponse
                        , handle NodesDisconnected
                        , handle DisconnectResponse
                        , handle NodeMetaUpdated
                        , handle NodeMetaResponse
                        , handle NodesUpdated
                        , handle MonadsUpdated
                        , handle NodeTypechecked
                        , handle ProgramFetched
                        , handle CodeUpdated
                        , handle NodeResultUpdated
                        , handle AddSubgraphResponse
                        , handle CollaborationUpdate
                        , handle ProjectList
                        , handle ProjectCreated
                        , handle ProjectCreatedUpdate
                        , handle ProjectOpened
                        , handle ProjectOpenedUpdate
                        , handle ProjectExported
                        , handle ProjectImported
                        , handle NodeRenamed
                        , handle UpdateNodeExpressionResponse
                        , handle NodeSearchResponse
                        , handle EmpireStarted
                        ]

processMessage :: WebMessage -> Batch.Event
processMessage (WebMessage topic bytes) = handler bytes where
    handler      = Map.findWithDefault defHandler topic handlers
    defHandler _ = UnknownEvent topic
processMessage (ControlMessage ConnectionTakeover) = ConnectionDropped
processMessage (ControlMessage Welcome)            = ConnectionOpened
