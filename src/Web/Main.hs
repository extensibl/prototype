{-# LANGUAGE OverloadedStrings #-}
module Main where

import qualified Instrument.VanillaOption as VO
import qualified Instrument.RainbowOption as RO
import qualified Instrument.Basket2Option as BO
import DataProviders.Database
import DataProviders.Data
import View
import Service
import PersistentData
import DB
import Serialization
import Data
import Utils
import qualified Stocks.FetchStocks as F
import System.Environment

import Data.Time
import Web.Scotty hiding (body, params, options)
import Data.Aeson (FromJSON)
import qualified Database.Persist.Sql as P
import System.Environment (getArgs)
import Control.Monad (when)
import System.Console.GetOpt
import Data.Time.Clock
import Data.Time.Calendar

instance FromJSON VO.VanillaOption
instance FromJSON RO.RainbowOption
instance FromJSON BO.Basket2Option

allContracts = [VO.vanillaOption, RO.rainbowOption, BO.basket2Option]
defaultPort = 3000
initialSymbols = ["AAPL", "GOOGL", "CAT", "YHOO", "SHLD", "IBM", "MSFT"]

data Flag = Port String | InitData
      deriving Show
   
options :: [OptDescr Flag]
options =
    [ Option ['i'] ["initdata"] (NoArg InitData)     "Fetch quotes for a number of stocks (e.g., AAPL and GOOGL) from Yahoo"
    , Option ['p'] ["port"]     (ReqArg Port "PORT") "Run server on specified port (3000 by default)"
    ]

appOpts :: [String] -> IO ([Flag], [String])
appOpts argv = 
    case getOpt Permute options argv of
      (o,n,[]  ) -> return (o,n)
      (_,_,errs) -> ioError (userError (concat errs ++ usageInfo header options))
    where header = "Usage: web [OPTION...]"
                   
main = do
  runDb $ P.runMigration migrateTables
  createDefaultUser
  createDefaultPortfolio
  initializeDataTables
  args <- getArgs
  params <- appOpts args
  port <- System.Environment.lookupEnv "PORT"
  case params of
    (opts@(o : _), _) -> mapM_ performAction opts
    ([],_) -> runServer (case port of
                            Just p -> (read p :: Int)
                            Nothing -> defaultPort)

performAction InitData = initData
performAction (Port portNum) = runServer $ read portNum

runServer port = scotty port $
  do
    api (url VO.vanillaOption) (jsonContract :: ActionM VO.VanillaOption) VO.makeContract
    api (url RO.rainbowOption) (jsonContract :: ActionM RO.RainbowOption) RO.makeContract
    api (url BO.basket2Option) (jsonContract :: ActionM BO.Basket2Option) BO.makeContract
    defaultService allContracts dbDataProvider

initData :: IO ()
initData = do
  currTime <- getCurrentTime
  let currDate = utctDay currTime
  putStrLn "Fetching initial data..."
  mapM_ (\x -> F.update_db_quotes x (formatDate (addDays (-90) currDate)) (formatDate currDate) "Yahoo") initialSymbols
  putStrLn "Done."
  return ()
                   
initializeDataTables = do
  quotes <- (runDb $ P.selectList [] []) :: IO [P.Entity DbQuotes]
  modelData <- (runDb $ P.selectList [] []) :: IO [P.Entity DbModelData]
  corr <- (runDb $ P.selectList [] []) :: IO [P.Entity DbCorr]
  when ((null quotes) && (null modelData) && (null corr)) $ insertFromCsv
