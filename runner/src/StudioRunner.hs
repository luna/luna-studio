{-# LANGUAGE ConstraintKinds       #-}
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE ExtendedDefaultRules  #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE PackageImports        #-}
{-# LANGUAGE FlexibleContexts      #-}

module Main where

import           Prelude
import qualified Control.Concurrent.Async      as Async
import           Control.Exception.Safe        (MonadMask, MonadCatch, bracket_, catch)
import           Control.Lens.Aeson
import           Control.Lens
import           Control.Monad
import           Control.Monad.IO.Class        (MonadIO, liftIO)
import           Control.Monad.State.Lazy
import qualified Data.ByteString.Lazy          as BL
import           Data.List.Split
import qualified Data.List                     as List
import           Data.Maybe                    (fromMaybe, maybeToList)
import           Data.Semigroup                ((<>))
import qualified "containers"  Data.Set        as Set
import           "containers"  Data.Set        (Set)
import qualified Data.Text                     as T
import qualified Data.Text.Encoding            as T
import           Options.Applicative
import           System.FilePath
import           System.Directory
import           System.Exit                   (ExitCode)
import           System.Process.Typed          (proc, shell, runProcess, runProcess_, setWorkingDir, readProcess_)
import           System.Environment            (getExecutablePath, getArgs, lookupEnv)
import qualified System.Environment            as Environment
import           System.IO.Error               (isDoesNotExistError)
import           System.IO.Temp                (createTempDirectory)
import           System.Host

default (T.Text)


data RunnerConfig = RunnerConfig { _versionFile            :: FilePath
                                 , _mainHomeDir            :: FilePath
                                 , _userConfigFolder       :: FilePath
                                 , _configFolder           :: FilePath
                                 , _configHomeFolder       :: FilePath
                                 , _storageDataHomeFolder  :: FilePath
                                 , _studioHome             :: FilePath
                                 , _logsFolder             :: FilePath
                                 , _atomPackageName        :: FilePath
                                 , _appName                :: FilePath
                                 , _supervisorFolder       :: FilePath
                                 , _supervisordFolder      :: FilePath
                                 , _supervisordBin         :: FilePath
                                 , _supervisorctlBin       :: FilePath
                                 , _supervisordConfig      :: FilePath
                                 , _atomFolder             :: FilePath
                                 , _thirdPartyFolder       :: FilePath
                                 , _backendBinsFolder      :: FilePath
                                 , _binsFolder             :: FilePath
                                 , _packageFolder          :: FilePath
                                 , _supervisorKillFolder   :: FilePath
                                 , _supervisorKillBin      :: FilePath
                                 , _atomBinPath            :: FilePath
                                 , _mainTmpDirectory       :: FilePath
                                 , _lunaProjects           :: FilePath
                                 , _tutorialsDirectory     :: FilePath
                                 , _userInfoFile           :: FilePath
                                 , _resourcesFolder        :: FilePath
                                 , _shareFolder            :: FilePath
                                 , _windowsFolder          :: FilePath
                                 }

makeLenses ''RunnerConfig

type MonadRun m = (MonadState RunnerConfig m, MonadIO m, MonadMask m)

instance Monad m => MonadHostConfig RunnerConfig 'Linux arch m where
    defaultHostConfig = return $ RunnerConfig
        { _versionFile            = "version.txt"
        , _mainHomeDir            = ".luna"
        , _userConfigFolder       = "user-config"
        , _configFolder           = "config"
        , _configHomeFolder       = "config"
        , _storageDataHomeFolder  = "storage"
        , _studioHome             = "atom"
        , _logsFolder             = "logs"
        , _atomPackageName        = "luna-studio"
        , _appName                = "luna-studio"
        , _supervisorFolder       = "supervisor"
        , _supervisordFolder      = "supervisord"
        , _supervisordBin         = "supervisord"
        , _supervisorctlBin       = "supervisorctl"
        , _supervisordConfig      = "supervisord-package.conf"
        , _atomFolder             = "atom"
        , _thirdPartyFolder       = "third-party"
        , _backendBinsFolder      = "private"
        , _binsFolder             = "bin"
        , _packageFolder          = "packages"
        , _supervisorKillFolder   = "kill"
        , _supervisorKillBin      = "kill"
        , _atomBinPath            = "atom" </> "usr" </> "bin" </> "atom"
        , _mainTmpDirectory       = "luna"
        , _lunaProjects           = "luna" </> "projects"
        , _tutorialsDirectory     = "tutorials"
        , _userInfoFile           = "user_info.json"
        , _resourcesFolder        = "public" </> "luna-studio" </> "resources"
        , _shareFolder            = ".local" </> "share"
        , _windowsFolder          = "windows"
        }

instance Monad m => MonadHostConfig RunnerConfig 'Darwin arch m where
    defaultHostConfig = reconfig <$> defaultHostConfigFor @Linux where
        reconfig cfg = cfg & atomBinPath .~ ("Atom.app" </> "Contents" </> "MacOS" </> "Atom")

instance Monad m => MonadHostConfig RunnerConfig 'Windows arch m where
    defaultHostConfig = reconfig <$> defaultHostConfigFor @Linux where
        reconfig cfg = cfg & atomBinPath .~ ("Atom" </> "atom.exe")

-- path helpers --
runnerDir :: MonadIO m => m FilePath
runnerDir = liftIO $ dropFileName <$> getExecutablePath

mainAppDir :: MonadIO m => m FilePath
mainAppDir = do
    runnerDir <- runnerDir
    -- Due to certain issues, two copies of luna-studio might be shipped:
    -- `bin/main/luna-studio` and `bin/public/luna-studio/luna-studio`
    -- Thus, we need to check where are we, to say where is the package root.
    -- This workaround should be removed once this issue is addressed:
    -- https://github.com/luna/luna-manager/issues/226
    let stepUp = if (last . splitDirectories) runnerDir == "main"
                 then takeDirectory . takeDirectory                 -- drop bin/main/
                 else takeDirectory . takeDirectory . takeDirectory -- drop bin/public/luna-studio/
    pure $ stepUp runnerDir

mainHomeFolder ::  MonadRun m => m FilePath
mainHomeFolder = do
  runnerCfg <- get @RunnerConfig
  home      <- liftIO getHomeDirectory
  return $ home </> (runnerCfg ^. mainHomeDir)

relativeToDir :: MonadRun m => m FilePath -> [Getting FilePath RunnerConfig FilePath] -> m FilePath
relativeToDir basePath segmentAccessors = do
    runnerCfg <- get @RunnerConfig
    base      <- basePath
    let pathSegments = map (runnerCfg ^.) segmentAccessors
    return $ foldl (</>) base pathSegments

relativeToMainDir, relativeToHomeDir :: MonadRun m => [Getting FilePath RunnerConfig FilePath] -> m FilePath
relativeToMainDir = relativeToDir mainAppDir
relativeToHomeDir = relativeToDir mainHomeFolder

versionText :: MonadRun m => m T.Text
versionText = do
    versionFP  <- versionFilePath
    versionStr <- liftIO $ readFile versionFP
    pure $ T.pack versionStr

version :: MonadRun m => m FilePath
version = do
    versionTxt <- versionText
    pure $ T.unpack versionTxt

printVersion :: (MonadRun m, MonadCatch m) => m ()
printVersion = do
    versionTxt <- catch versionText $ \e -> return $ if (isDoesNotExistError e) then "develop" else T.pack $ show e
    liftIO $ print versionTxt

-- paths --
backendBinsPath, configPath, atomAppPath, backendDir                           :: MonadRun m => m FilePath
supervisordBinPath, supervisorctlBinPath, killSupervisorBinPath                :: MonadRun m => m FilePath
packageStudioAtomHome, userStudioAtomHome, localLogsDirectory, versionFilePath :: MonadRun m => m FilePath
resourcesDirectory, windowsLogsDirectory                                       :: MonadRun m => m FilePath
userLogsDirectory, userdataStorageDirectory, localdataStorageDirectory         :: MonadRun m => m FilePath
lunaTmpPath, lunaProjectsPath, lunaTutorialsPath, userInfoPath                 :: MonadRun m => m FilePath
sharePath, windowsScriptsPath, backendLdLibraryPath                            :: MonadRun m => m FilePath

backendBinsPath           = relativeToMainDir [binsFolder, backendBinsFolder]
configPath                = relativeToMainDir [configFolder]
atomAppPath               = relativeToMainDir [thirdPartyFolder, atomBinPath]
backendDir                = relativeToMainDir [configFolder, supervisorFolder]
supervisordBinPath        = relativeToMainDir [thirdPartyFolder, supervisordFolder, supervisordBin]
supervisorctlBinPath      = relativeToMainDir [thirdPartyFolder, supervisordFolder, supervisorctlBin]
killSupervisorBinPath     = relativeToMainDir [thirdPartyFolder, supervisorKillFolder, supervisorKillBin]
packageStudioAtomHome     = relativeToMainDir [userConfigFolder, studioHome]
localLogsDirectory        = relativeToMainDir [logsFolder]
versionFilePath           = relativeToMainDir [configFolder, versionFile]
resourcesDirectory        = relativeToMainDir [binsFolder, resourcesFolder]
windowsLogsDirectory      = relativeToMainDir [configFolder, logsFolder]
userLogsDirectory         = relativeToHomeDir [logsFolder, appName] >>= (\p -> (fmap (p </>) version))
userdataStorageDirectory  = relativeToHomeDir [configHomeFolder, appName, storageDataHomeFolder]
localdataStorageDirectory = relativeToHomeDir [storageDataHomeFolder]
userInfoPath              = relativeToHomeDir [userInfoFile]
sharePath                 = relativeToDir (liftIO getHomeDirectory) [shareFolder]
windowsScriptsPath        = relativeToMainDir [configFolder, windowsFolder]
userStudioAtomHome = do
    runnerCfg <- get @RunnerConfig
    baseDir   <- relativeToHomeDir [configHomeFolder, appName] >>= (\p -> (fmap (p </>) version))
    return $ baseDir </> (runnerCfg ^. studioHome)
lunaTmpPath       = do
    runnerCfg  <- get @RunnerConfig
    systemTmp  <- liftIO getTemporaryDirectory
    lunaTmpDir <- liftIO $ createTempDirectory systemTmp $ runnerCfg ^. mainTmpDirectory
    return lunaTmpDir
lunaProjectsPath  = do
    runnerCfg <- get @RunnerConfig
    home      <- liftIO getHomeDirectory
    return $ home </> (runnerCfg ^. lunaProjects)
lunaTutorialsPath = do
    runnerCfg <- get @RunnerConfig
    lunaTmp   <- lunaTmpPath
    return $ lunaTmp </> (runnerCfg ^. tutorialsDirectory)
backendLdLibraryPath = do
    ldLibPath <- liftIO $ getCurrentDirectory
    return $ ldLibPath </> "lib" </> "zeromq"



atomHomeDir, logsDir, windowsLogsDir, dataStorageDirectory :: MonadRun m => Bool -> m FilePath
atomHomeDir          develop = if develop then packageStudioAtomHome     else userStudioAtomHome
logsDir              develop = if develop then localLogsDirectory        else userLogsDirectory
windowsLogsDir       develop = if develop then localLogsDirectory        else windowsLogsDirectory
dataStorageDirectory develop = if develop then localdataStorageDirectory else userdataStorageDirectory
-- misc runner utils --

windows, linux, darwin, unix :: Bool
windows = currentHost == Windows
linux   = currentHost == Linux
darwin  = currentHost == Darwin
unix    = not windows

unixOnly :: MonadRun m => m () -> m ()
unixOnly act = case currentHost of
    Windows -> liftIO $ putStrLn "Current host (Windows) not supported for this operation"
    _       -> act

setEnv :: MonadRun m => String -> String -> m ()
setEnv name val = liftIO $ Environment.setEnv name val

copyLunaStudio :: MonadRun m => m ()
copyLunaStudio = do
    mainHomePath    <- mainHomeFolder
    packageAtomHome <- packageStudioAtomHome
    atomHomeParent  <- takeDirectory <$> userStudioAtomHome
    liftIO $ do
      createDirectoryIfMissing True atomHomeParent
      -- TODO: find a library that can handle recursive copies while preserving symlinks on unix
      if currentHost == Windows
      then do
        runProcess_ $ proc "robocopy" [packageAtomHome, atomHomeParent, "/e"]
        runProcess_ $ proc "attrib" ["+h", mainHomePath]
      else
        runProcess_ $ proc "cp" ["-r", packageAtomHome, atomHomeParent]

copyResourcesLinux :: MonadRun m => m ()
copyResourcesLinux = when linux $ do
    runnerCfg <- get @RunnerConfig
    versionN  <- T.strip <$> versionText
    resources <- resourcesDirectory
    localShareFolder <- sharePath
    let iconsFolder  = resources </> "icons"
        desktopFile  = resources </> "app_shared.desktop"
        localDesktop = localShareFolder </> "applications" </> T.unpack (T.concat ["LunaStudio", versionN, ".desktop"])
    liftIO $ do
      createDirectoryIfMissing True $ takeDirectory localShareFolder
      createDirectoryIfMissing True $ takeDirectory localDesktop
      -- TODO: find a library that can handle recursive copies while preserving symlinks on unix
      runProcess_ $ proc "cp" ["-r", iconsFolder, localShareFolder]
      copyFileWithMetadata desktopFile localDesktop

testDirectory :: MonadIO m => FilePath -> m Bool
testDirectory path =
    liftIO $ canonicalizePath path >>= doesDirectoryExist

createStorageDataDirectory :: MonadRun m => Bool -> m ()
createStorageDataDirectory develop = do
    dataStoragePath <- dataStorageDirectory develop
    liftIO $ createDirectoryIfMissing True dataStoragePath

checkLunaHome :: MonadRun m => m ()
checkLunaHome = do
    runnerCfg    <- get @RunnerConfig
    userAtomHome <- userStudioAtomHome
    let pathLunaPackage = userAtomHome </> (runnerCfg ^. packageFolder) </> (runnerCfg ^. atomPackageName)
    testDirectory pathLunaPackage >>= (\exists -> unless exists copyLunaStudio)

-- supervisord --
supervisorctl :: MonadRun m => [T.Text] -> m T.Text
supervisorctl args = do
    supervisorBinPath <- supervisorctlBinPath
    supervisorDir <- backendDir
    let runSupervisorctl = readProcess_ $ setWorkingDir supervisorDir
                                        $ proc supervisorBinPath $ map T.unpack args
        supressErrors act = do
          a <- Async.async act
          either (const "Unable to run supervisorctl") (T.decodeUtf8 . BL.toStrict . fst) <$> Async.waitCatch a
    liftIO $ supressErrors runSupervisorctl

supervisord :: MonadRun m => FilePath -> m ()
supervisord configFile = do
    supervisorBinPath <- supervisordBinPath
    supervisorDir <- backendDir
    ldLibPath <- liftIO $ lookupEnv "LD_LIBRARY_PATH"
    setEnv "OLD_LIBPATH" $ fromMaybe "\"\"" ldLibPath
    runProcess_ $ setWorkingDir supervisorDir
                $ shell $ supervisorBinPath ++ " -n -c " ++ configFile

stopSupervisor :: MonadRun m => m ()
stopSupervisor = void $ supervisorctl ["shutdown"]

testIfRunning :: MonadRun m => m Bool
testIfRunning = do
    -- TODO[piotrMocz]: we'll need a more robust method eventually
    -- this merely check if there's any luna-related app running
    let lunaApps = Set.fromList ["luna-broker", "luna-ws-connector", "luna-empire", "luna-atom", "luna-undo-redo"] :: Set T.Text
    runningApps <- Set.fromList . T.words <$> supervisorctl ["status", "all"]
    return . not . Set.null $ Set.intersection runningApps lunaApps

-- runner functions --
runLunaEmpire :: MonadRun m => FilePath -> FilePath -> Bool -> m ()
runLunaEmpire logs configFile forceRun = do
    -- NOTE[piotrMocz]: when the `forceRun` flag is set, we will stop any
    -- running instances of supervisord and proceed. If not, they will prevent
    -- the application from running
    running <- testIfRunning
    if running && (not forceRun) then liftIO $ putStrLn "LunaStudio is already running"
    else do
        when running stopSupervisor
        liftIO $ createDirectoryIfMissing True logs
        supervisord configFile

runFrontend :: MonadRun m => Maybe T.Text -> m ()
runFrontend args = do
    atom <- atomAppPath
    createStorageDataDirectory True
    liftIO $ Environment.setEnv "LUNA_STUDIO_DEVELOP" "True"
    setEnv "ATOM_HOME"             =<< packageStudioAtomHome
    setEnv "LUNA_STUDIO_DATA_PATH" =<< dataStorageDirectory True
    setEnv "LUNA_TMP"              =<< lunaTmpPath
    setEnv "LUNA_PROJECTS"         =<< lunaProjectsPath
    setEnv "LUNA_TUTORIALS"        =<< lunaTutorialsPath
    setEnv "LUNA_USER_INFO"        =<< userInfoPath
    setEnv "LUNA_VERSION_PATH"     =<< versionFilePath
    unixOnly $ liftIO $ runProcess_ $ proc atom $ map T.unpack $ "-w" : maybeToList args

runBackend :: MonadRun m => Bool -> m ()
runBackend forceRun = do
    logs <- localLogsDirectory
    setEnv "LUNA_STUDIO_LOG_PATH"     =<< localLogsDirectory
    setEnv "LUNA_STUDIO_BACKEND_PATH" =<< backendBinsPath
    setEnv "LUNA_STUDIO_CONFIG_PATH"  =<< configPath
    unixOnly $ runLunaEmpire logs "supervisord.conf" forceRun

startServices :: MonadRun m => m ()
startServices = case currentHost of
    Windows -> do
        path <- windowsScriptsPath
        liftIO $ runProcess_ $ setWorkingDir path $ shell "start.bat"
    _       -> return ()

stopServices :: MonadRun m => m ()
stopServices = case currentHost of
    Windows -> do
        path <- windowsScriptsPath
        liftIO $ runProcess_ $ setWorkingDir path $ shell "stop.bat"
    _       -> return ()

runPackage :: MonadRun m => Bool -> Bool -> m ()
runPackage develop forceRun = case currentHost of
    Windows -> do
        atom <- atomAppPath
        checkLunaHome
        setEnv "LUNA_STUDIO_DATA_PATH" =<< dataStorageDirectory develop
        setEnv "LUNA_STUDIO_LOG_PATH"  =<< windowsLogsDir       develop
        setEnv "ATOM_HOME"             =<< userStudioAtomHome
        setEnv "LUNA_TMP"              =<< lunaTmpPath
        setEnv "LUNA_PROJECTS"         =<< lunaProjectsPath
        setEnv "LUNA_TUTORIALS"        =<< lunaTutorialsPath
        setEnv "LUNA_USER_INFO"        =<< userInfoPath
        setEnv "LUNA_VERSION_PATH"     =<< versionFilePath
        createStorageDataDirectory develop
        bracket_ startServices stopServices $ liftIO $ runProcess_ $ shell atom

    _ -> do
        runnerCfg <- get @RunnerConfig
        logs      <- logsDir develop
        let supervisorConf = runnerCfg ^. supervisordConfig
        setEnv "LUNA_STUDIO_DATA_PATH"       =<< dataStorageDirectory develop
        setEnv "LUNA_STUDIO_GUI_CONFIG_PATH" =<< atomHomeDir          develop
        setEnv "LUNA_STUDIO_LOG_PATH"        =<< logsDir              develop
        setEnv "LUNA_STUDIO_BACKEND_PATH"    =<< backendBinsPath
        setEnv "LUNA_STUDIO_GUI_PATH"        =<< atomAppPath
        setEnv "LUNA_STUDIO_CONFIG_PATH"     =<< configPath
        setEnv "LUNA_STUDIO_KILL_PATH"       =<< killSupervisorBinPath
        setEnv "LUNA_TMP"                    =<< lunaTmpPath
        setEnv "LUNA_PROJECTS"               =<< lunaProjectsPath
        setEnv "LUNA_TUTORIALS"              =<< lunaTutorialsPath
        setEnv "LUNA_USER_INFO"              =<< userInfoPath
        setEnv "LUNA_VERSION_PATH"           =<< versionFilePath
        when develop   $ liftIO $ Environment.setEnv "LUNA_STUDIO_DEVELOP" "True"
        if develop then
            liftIO $ Environment.setEnv "LUNA_STUDIO_BACKEND_LD_LIBRARY_PATH" "\"\""
            else setEnv "LUNA_STUDIO_BACKEND_LD_LIBRARY_PATH" =<< backendLdLibraryPath
        createStorageDataDirectory develop
        unless develop $ do
            checkLunaHome
            copyResourcesLinux
        runLunaEmpire logs supervisorConf forceRun

runApp :: MonadRun m => Bool -> Bool -> Maybe String -> m ()
runApp develop forceRun atom = do
    setEnv "LUNA_STUDIO_ATOM_ARG" (fromMaybe " " atom)
    runPackage develop forceRun

data Options = Options
    { frontend :: Bool
    , backend  :: Bool
    , develop  :: Bool
    , forceRun :: Bool
    , atom     :: Maybe String
    , versioncheck  :: Bool
    } deriving Show

optionParser :: Parser Options
optionParser = Options
    <$> switch (long "frontend"   <> short 'f')
    <*> switch (long "backend"    <> short 'b')
    <*> switch (long "develop"    <> short 'd')
    <*> switch (long "force-run"  <> short 'r')
    <*> (optional $ strOption $ long "atom" <> short 'a')
    <*> switch (long "version")

run :: Options -> IO ()
run (Options frontend backend develop forceRun atom versionCheck) = do
    hostConfig <- defHostConfig @RunnerConfig
    flip evalStateT hostConfig $ do
        if versionCheck then printVersion
        else if  frontend
        then runFrontend $ T.pack <$> atom
        else if backend
        then runBackend forceRun
        else runApp develop forceRun atom

filterArg :: String -> Bool
filterArg = not . List.isInfixOf "-psn"

filterArgs :: [String] -> [String]
filterArgs = filter filterArg

filteredParser :: ParserPrefs -> ParserInfo a -> IO a
filteredParser pprefs pinfo = execParserPure pprefs pinfo . filterArgs <$> getArgs >>= handleParseResult

parser :: MonadIO m => m Options
parser = liftIO $ filteredParser p opts
    where
        opts = info (optionParser <**> helper) idm
        p    = prefs showHelpOnEmpty

main :: IO ()
main = run =<< parser
