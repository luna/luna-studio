module ProjectManager.Repository.Project where

import Prologue

import qualified Control.Lens.Aeson as LensAeson
import qualified ProjectManager.Model.Project as Project
import qualified System.Environment as Env
import qualified Control.Monad.State.Layered as State
import qualified Path
import qualified Data.Map as Map
import qualified Data.Yaml as Yaml
import qualified Data.UUID.V4 as UUID
import qualified Path.IO            as PathIO
import qualified Luna.Package.Configuration.Local as Config
import qualified Luna.Package as Package

import ProjectManager.Model.Project (Project)
import Path (Path, Abs, Rel, Dir, File, (</>))
import Data.Map (Map)
import Data.UUID (UUID)

type ProjectId = UUID

data CacheItem = CacheItem
    { _path     :: Path Abs Dir
    , _id       :: ProjectId
    , _lastOpen :: Maybe Int64
    } deriving (Generic)

instance Yaml.FromJSON CacheItem where
    parseJSON = LensAeson.parseYamlStyle

instance Yaml.ToJSON CacheItem where
    toJSON     = LensAeson.toJSONYamlStyle
    toEncoding = LensAeson.toEncodingYamlStyle

makeLenses ''CacheItem


data State = State
    { _projects  :: Map ProjectId Project
    , _cachePath :: Path Abs File
    , _projectsRootPath :: Path Abs Dir
    }

makeLenses ''State

mkState :: Path Abs File -> Path Abs Dir -> State
mkState = State def

type MonadRepo m = (MonadIO m, State.Monad State m)
type RepoT m     = State.StateT State m

getCachePath :: MonadIO m => m (Path Abs File)
getCachePath = do
    dataPath <- liftIO $ Path.parseAbsDir =<< Env.getEnv "LUNA_STUDIO_DATA_PATH"
    pure $ dataPath </> $(Path.mkRelFile "projects-cache.yaml")

getProjectsRootPath :: MonadIO m => m (Path Abs Dir)
getProjectsRootPath = liftIO $
    Path.parseAbsDir =<< Env.getEnv "LUNA_PROJECTS"

readProjectsCache :: MonadIO m => Path Abs File -> m [CacheItem]
readProjectsCache path = liftIO $
    Yaml.decodeFileEither (Path.toFilePath path) >>= \case
        Left  err   -> pure mempty
        Right cache -> pure cache

listProjectsInDirectory :: MonadIO m => Path Abs Dir -> m [Project]
listProjectsInDirectory container = do
    subdirs <- fst <$> PathIO.listDir container
    configs <- fmap catMaybes $ for subdirs $ \path ->
        (path,) <<$>> Package.tryGetConfigFile path
    for configs $ \(path, cfg) ->
        pure $ Project.Project path cfg def

initialize :: MonadRepo m => m ()
initialize = do
    cachePath' <- State.use @State cachePath
    projectsRootPath' <- State.use @State projectsRootPath
    cache <- readProjectsCache cachePath'
    let cacheMapping = Map.fromList $ (\(CacheItem path id lastOpen) -> (path, (id, lastOpen))) <$> cache
    realProjects <- listProjectsInDirectory projectsRootPath'
    projectMapping <- fmap Map.fromList $ for realProjects $ \project ->
        case Map.lookup (project ^. Project.path) cacheMapping of
            Nothing -> do
                uuid <- liftIO $ UUID.nextRandom
                pure (uuid, project)
            Just (id, lastOpen) -> pure (id, project & Project.lastOpen .~ lastOpen)
    state <- State.get @State
    State.put @State $ state & projects .~ projectMapping

saveCache :: MonadRepo m => m ()
saveCache = do
    projects'  <- State.use @State projects
    let buildCacheItem (id, project) = CacheItem (project ^. Project.path) id (project ^. Project.lastOpen)
        cacheItems = buildCacheItem <$> Map.toList projects'
    cachePath' <- State.use @State cachePath
    liftIO $ Yaml.encodeFile (Path.toFilePath cachePath') cacheItems

getProjects :: MonadRepo m => m (Map ProjectId Project)
getProjects = State.use @State projects

run :: MonadIO m => RepoT m a -> m a
run action = do
    cachePath <- getCachePath
    projectsRootPath <- getProjectsRootPath
    flip State.evalT (mkState cachePath projectsRootPath) $ do
        initialize
        saveCache
        action


