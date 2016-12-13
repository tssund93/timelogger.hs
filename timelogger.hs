module Main where

import Data.Maybe
import Data.Time
import System.IO

version :: String
version = "0.0.1"

data TimeLog = TimeLog { records :: Records
                       , current :: Maybe Record
                       } deriving (Show, Eq)

type Records = [Record]
data Record = Record { recordNum :: String
                     , inTime :: UTCTime
                     , outTime :: Maybe UTCTime
                     , description :: Maybe String
                     , billable :: Maybe Bool
                     } deriving (Show, Eq)

main :: IO ()
main = do
  putStrLn $ "Timelogger v" ++ version
  putStrLn "Press \"h\" for help\n"
  currentTime <- getCurrentTime
  let currentDay = utctDay currentTime
  mainLoop currentDay (Just $ TimeLog [] Nothing)

mainLoop :: Day -> Maybe TimeLog -> IO ()
mainLoop day (Just timeLog) = do
  printPrompt timeLog day
  command <- getLine
  result <- handleCommand day timeLog command
  if (null result)
    then return ()
    else do
      let newDay = snd $ fromJust result
          newLog = fst $ fromJust result
      mainLoop newDay (Just newLog)
mainLoop _ Nothing = return ()

printPrompt :: TimeLog -> Day -> IO ()
printPrompt timeLog day = do
  let curr = current timeLog
  putStrLn $ "Current date: " ++ (formatTime defaultTimeLocale "%D" day) ++ printCurrInfo curr
  currentTime <- getCurrentTime
  putStr $ (formatTime defaultTimeLocale "%R" currentTime) ++ "> "
  hFlush stdout

printCurrInfo :: Maybe Record -> String
printCurrInfo (Just curr) =
  " (Current: " ++ (recordNum curr) ++ ")"
printCurrInfo Nothing = ""

handleCommand :: Day -> TimeLog -> String -> IO (Maybe (TimeLog,Day))
handleCommand day timeLog [] = return $ Just (timeLog,day)
handleCommand _ _ ('q':_) = return Nothing
handleCommand day timeLog ('c':_) = do
  newLog <- handleClockInOut timeLog day
  return $ Just (newLog,day)
handleCommand _ timeLog ('d':_) = do
  newDay <- prompt "Enter new date: "
  parsedDay <- parseTimeM True defaultTimeLocale "%D" (fromJust newDay)
  return $ Just (timeLog,parsedDay)
handleCommand day timeLog ('l':_) = do
  printLog timeLog
  return $ Just (timeLog,day)
handleCommand day timeLog cmd = do
  putStrLn $ "Invalid command: " ++ cmd
  return $ Just (timeLog,day)

handleClockInOut :: TimeLog -> Day -> IO TimeLog
handleClockInOut timeLog day = do
  currentTime <- getCurrentTime
  let currentDay = utctDay currentTime
  if (day == currentDay)
    then do
      newLog <- if (clockedIn timeLog) then (clockOut timeLog) else (clockIn timeLog)
      return newLog
    else do
      putStrLn "You must be on today's date to clock in or out."
      return timeLog

clockedIn :: TimeLog -> Bool
clockedIn timeLog = isJust (current timeLog)

clockIn :: TimeLog -> IO TimeLog
clockIn timeLog = do
  num <- prompt "Enter item ID: "
  if (null num)
    then do
      putStrLn "Canceled"
      return timeLog
    else do
      currentTime <- getCurrentTime
      return $ TimeLog (records timeLog) (Just $ Record (fromJust num) currentTime Nothing Nothing Nothing)

clockOut :: TimeLog -> IO TimeLog
clockOut timeLog = do
  desc <- prompt "Enter a description of what you worked on: "
  if (null desc)
    then do
      putStrLn "Canceled"
      return timeLog
    else do
      bill <- promptYN "Was this work billable?"
      currentTime <- getCurrentTime
      let curr = fromJust $ current timeLog
          newRecord = Record (recordNum curr) (inTime curr) (Just currentTime) desc (Just bill)
      return $ TimeLog (newRecord : records timeLog) Nothing

prompt :: String -> IO (Maybe String)
prompt s = do
  putStr s
  hFlush stdout
  response <- getLine
  if (null response)
    then return Nothing
    else return $ Just response

promptYN :: String -> IO Bool
promptYN s = do
  putStr $ s ++ " (y or n) "
  hFlush stdout
  getLine >>= readYorN

readYorN :: String -> IO Bool
readYorN "y" = return True
readYorN "n" = return False
readYorN _ = do
  putStr "Please type \"y\" for yes or \"n\" for no. "
  getLine >>= readYorN

printLog :: TimeLog -> IO ()
printLog timeLog = do
  putStrLn $ show timeLog
