-- Copyright 2019 Google LLC
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE file or at
-- https://developers.google.com/open-source/licenses/bsd

module Live.Web (runWeb) where

import Control.Concurrent (readChan)
import Control.Monad (forever)

import Network.Wai (Application, StreamingBody, pathInfo,
                    responseStream, responseLBS, responseFile)
import Network.Wai.Handler.Warp (run)
import Network.HTTP.Types (status200, status404)
import Data.Aeson (ToJSON, encode)
import Data.Binary.Builder (fromByteString)
import Data.ByteString.Lazy (toStrict)
import qualified Data.ByteString as BS

import Paths_dex (getDataFileName)

import Live.Eval
import TopLevel

runWeb :: FilePath -> EvalConfig -> TopStateEx -> IO ()
runWeb fname opts env = do
  resultsChan <- watchAndEvalFile fname opts env
  putStrLn "Streaming output to http://localhost:8000/"
  run 8000 $ serveResults resultsChan

serveResults :: ResultsServer -> Application
serveResults resultsSubscribe request respond = do
  print (pathInfo request)
  case pathInfo request of
    []            -> respondWith "static/dynamic.html" "text/html"
    ["style.css"] -> respondWith "static/style.css"  "text/css"
    ["index.js"]  -> respondWith "static/index.js"   "text/javascript"
    ["getnext"]   -> respond $ responseStream status200
                       [ ("Content-Type", "text/event-stream")
                       , ("Cache-Control", "no-cache")]
                       $ resultStream resultsSubscribe
    _ -> respond $ responseLBS status404
           [("Content-Type", "text/plain")] "404 - Not Found"
  where
    respondWith dataFname ctype = do
      fname <- return dataFname -- lets us skip rebuilding during development
      -- fname <- getDataFileName dataFname
      respond $ responseFile status200 [("Content-Type", ctype)] fname Nothing

resultStream :: ResultsServer -> StreamingBody
resultStream resultsServer write flush = do
  write (fromByteString $ encodeResults ("start"::String)) >> flush
  (initResult, resultsChan) <- subscribeIO resultsServer
  sendUpdate $ dagAsUpdate initResult
  forever $ readChan resultsChan >>= sendUpdate
  where
    sendUpdate :: ResultsUpdate -> IO ()
    sendUpdate update = do
      let s = encodeResults update
      write (fromByteString s) >> flush

    encodeResults :: ToJSON a => a -> BS.ByteString
    encodeResults = toStrict . wrap . encode
      where wrap s = "data:" <> s <> "\n\n"
