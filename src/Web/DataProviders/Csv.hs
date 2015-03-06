module DataProviders.Csv where

import CodeGen.DataGen
import Contract.Date
import DataProviders.Data
import Utils

import Data.Time
import Data.Csv
import Data.List
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Char8 as B
import qualified Data.Vector as V

instance FromField Day where
    parseField s = return $ parseDate $ B.unpack s

quotesFile = "./src/Web/sampledata/Quotes.csv"
corrsFile = "./src/Web/sampledata/Correlations.csv"
modelDataFile = "./src/Web/sampledata/ModelData.csv"

-- TODO: think about correlations. We not filtering them here.
-- Maybe better use separate functions for corrs and qoutes. 
getRawData :: [String] -> Day -> Day -> IO ([RawQuotes],[RawCorr])
getRawData unds fromD toD = 
    do
      quotes <- getStoredQuotes
      corrs <- getStoredCorrs
      return $ (filterQuotes unds fromD toD quotes, corrs)

filterQuotes :: [String] -> Day -> Day -> [RawQuotes] -> [RawQuotes]
filterQuotes unds fromD toD qs = [q | q@(und_, d, p) <- qs, und_ `elem` unds && fromD <= d && d <= toD ]

availableUnderlyings :: IO [String]
availableUnderlyings = do
  rawQuotes <- getStoredQuotes
  return $ nub [ und | (und, _, _) <- rawQuotes]

getStoredQuotes :: IO [RawQuotes]
getStoredQuotes = do
  csvQuotes <- BL.readFile quotesFile
  let quotes = case decode NoHeader csvQuotes of
                     Left err -> error err
                     Right v -> V.toList v
  return quotes

getStoredCorrs :: IO [RawCorr]
getStoredCorrs = do
  csvCorrs <- BL.readFile corrsFile
  let corrs = case decode NoHeader csvCorrs of
                     Left err -> error err
                     Right v -> V.toList v
  return corrs

getRawModelData :: String -> Day -> Day -> IO [RawModelData]
getRawModelData und fromD toD  = do
  csvMd <- BL.readFile modelDataFile
  let md = case decode NoHeader csvMd  of
             Left err -> error err
             Right v -> V.toList v
  return $ filterRawModelData und fromD toD md

filterRawModelData und fromD toD xs = [q | q@(und_, d, p) <- xs, und_ == und && fromD <= d && d <= toD ]
