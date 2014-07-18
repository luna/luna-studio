---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Flowbox.FileManager.Handler.Directory where

import qualified Flowbox.AWS.S3.Directory                                        as Directory
import           Flowbox.Bus.RPC.RPC                                             (RPC)
import           Flowbox.FileManager.Context                                     (Context)
import qualified Flowbox.FileManager.Context                                     as Context
import           Flowbox.Prelude                                                 hiding (Context)
import           Flowbox.System.Log.Logger
import           Flowbox.Tools.Serialize.Proto.Conversion.Basic
import qualified Generated.Proto.FileManager.FileSystem.Directory.Copy.Request   as Copy
import qualified Generated.Proto.FileManager.FileSystem.Directory.Copy.Update    as Copy
import qualified Generated.Proto.FileManager.FileSystem.Directory.Create.Request as Create
import qualified Generated.Proto.FileManager.FileSystem.Directory.Create.Update  as Create
import qualified Generated.Proto.FileManager.FileSystem.Directory.Exists.Request as Exists
import qualified Generated.Proto.FileManager.FileSystem.Directory.Exists.Status  as Exists
import qualified Generated.Proto.FileManager.FileSystem.Directory.Fetch.Request  as Fetch
import qualified Generated.Proto.FileManager.FileSystem.Directory.Fetch.Status   as Fetch
import qualified Generated.Proto.FileManager.FileSystem.Directory.List.Request   as List
import qualified Generated.Proto.FileManager.FileSystem.Directory.List.Status    as List
import qualified Generated.Proto.FileManager.FileSystem.Directory.Move.Request   as Move
import qualified Generated.Proto.FileManager.FileSystem.Directory.Move.Update    as Move
import qualified Generated.Proto.FileManager.FileSystem.Directory.Remove.Request as Remove
import qualified Generated.Proto.FileManager.FileSystem.Directory.Remove.Update  as Remove
import qualified Generated.Proto.FileManager.FileSystem.Directory.Upload.Request as Upload
import qualified Generated.Proto.FileManager.FileSystem.Directory.Upload.Status  as Upload



loggerIO :: LoggerIO
loggerIO = getLoggerIO "Flowbox.FileManager.Handler.Directory"

------ public api -------------------------------------------------


upload :: Context -> Upload.Request -> RPC IO Upload.Status
upload ctx (Upload.Request tpath) = do
    let path = decodeP tpath
    Context.run ctx $ Directory.upload "." path
    return $ Upload.Status tpath


fetch :: Context -> Fetch.Request -> RPC IO Fetch.Status
fetch ctx (Fetch.Request tpath) = do
    let path = decodeP tpath
    Context.run ctx $ Directory.fetch "." path
    return $ Fetch.Status tpath


create :: Context -> Create.Request -> RPC IO Create.Update
create ctx (Create.Request tpath) = do
    let path = decodeP tpath
    Context.run ctx $ Directory.create path
    return $ Create.Update tpath


exists :: Context -> Exists.Request -> RPC IO Exists.Status
exists ctx (Exists.Request tpath) = do
    let path = decodeP tpath
    e <- Context.run ctx $ Directory.exists path
    return $ Exists.Status e tpath


list :: Context -> List.Request -> RPC IO List.Status
list ctx (List.Request tpath) = do
    let path = decodeP tpath
    contents <- Context.run ctx $ Directory.getContents path
    return $ List.Status (encodeListP contents) tpath


remove :: Context -> Remove.Request -> RPC IO Remove.Update
remove ctx (Remove.Request tpath) = do
    let path = decodeP tpath
    Context.run ctx $ Directory.remove path
    return $ Remove.Update tpath


copy :: Context -> Copy.Request -> RPC IO Copy.Update
copy ctx (Copy.Request tsrc tdst) = do
    let src = decodeP tsrc
        dst = decodeP tdst
    Context.run ctx $ Directory.copy src dst
    return $ Copy.Update tsrc tdst


move :: Context -> Move.Request -> RPC IO Move.Update
move ctx (Move.Request tsrc tdst) = do
    let src = decodeP tsrc
        dst = decodeP tdst
    Context.run ctx $ Directory.copy src dst
    return $ Move.Update tsrc tdst
