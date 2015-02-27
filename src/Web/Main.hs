{-# LANGUAGE OverloadedStrings #-}
module Main where

import qualified CallOption as CO
import qualified RainbowOption as RO
import Pricing
import DataProviders.Csv 
import Data
import View
import Service
import TypeClass
import CodeGen.DataGen

import Data.Time
import Web.Scotty hiding (body, params)
import Data.Aeson (FromJSON)

instance FromJSON CO.CallOption
instance FromJSON RO.RainbowOption

allContracts = [CO.callOption, RO.rainbowOption]

pConf = DataConf { monteCarloIter = 4000000 }

main = scotty 3000 $ do
    api "callOption"    pConf (jsonData :: ActionM CO.CallOption)
    api "rainbowOption" pConf (jsonData :: ActionM RO.RainbowOption)
    defaultService allContracts availableUnderlyings getStoredQuotes
