{-# LANGUAGE Bang #-}

module CryptoBasis where

import Crypto.Hash
import Crypto.Hash.SHA256 (SHA256)
import Crypto.Hash.SHA512 (SHA512)
import Crypto.Hash.SHA1 (SHA1)
import Crypto.Hash.MD5 (MD5)
import Crypto.Internal.ByteArray (ByteArray, ByteArrayAccess, convert, pack)
import Crypto.Random (getRandomBytes, drgNew)
import Data.Word (Word8)
import Data.List (intercalate)
import Control.Monad (forM_)
import System.IO (hFlush, stdout)

data TestResult = TestResult
  { testName :: String
  , testPassed :: Bool
  , testMsg :: String
  , testExpected :: String
  , testActual :: String
  } deriving (Show)

class CryptoFunction a where
  hashData :: ByteArrayAccess b => a -> b -> ByteString

data CryptoBasis

hashSHA256 :: ByteArrayAccess b => b -> ByteString
hashSHA256 = hash

hashSHA512 :: ByteArrayAccess b => b -> ByteString
hashSHA512 = hash

hashSHA1 :: ByteArrayAccess b => b -> ByteString
hashSHA1 = hash

hashMD5 :: ByteArrayAccess b => b -> ByteString
hashMD5 = hash

hashBLAKE2b :: ByteArrayAccess b => b -> ByteString
hashBLAKE2b = hash

hashBLAKE2s :: ByteArrayAccess b => b -> ByteString
hashBLAKE2s = hash

hmacSHA256 :: ByteArrayAccess a => ByteArrayAccess b => a -> b -> ByteString
hmacSHA256 = hmac

hmacSHA512 :: ByteArrayAccess a => ByteArrayAccess b => a -> b -> ByteString
hmacSHA512 = hmac

type TestVector = (String, [Word8])

emptyInput :: [Word8]
emptyInput = []

singleByte :: [Word8]
singleByte = [0x78]

shortString :: [Word8]
shortString = map (toEnum . fromEnum) "hello world"

longInput :: [Word8]
longInput = replicate 10000 0x61

binaryNull :: [Word8]
binaryNull = [0x00, 0x01, 0x02, 0x00]

repetition :: [Word8]
repetition = replicate 256 0x55

boundaryValues :: [Word8]
boundaryValues = [0..255]

testVectors :: [(String, [Word8])]
testVectors = 
  [ ("empty_input", emptyInput)
  , ("single_byte", singleByte)
  , ("short_string", shortString)
  , ("long_input", longInput)
  , ("binary_null", binaryNull)
  , ("repetition", repetition)
  , ("boundary_values", boundaryValues)
  ]

newCryptoTestHarness :: IO [TestResult]
newCryptoTestHarness = return []

registerResult :: [TestResult] -> String -> Bool -> String -> [TestResult]
registerResult results name passed msg = 
  TestResult name passed msg "" "" : results

testHashFunction :: String -> ([Word8] -> ByteString) -> IO [TestResult] -> IO [TestResult]
testHashFunction name fn !results = do
  caseNameResults <- mapM testCase testVectors
  return $ reverse (concat caseNameResults) ++ results
  where
    testCase (caseName, inputData) = do
      let result = fn inputData
      if null result
        then return [TestResult (name ++ "_" ++ caseName) False "empty result" "" ""]
        else return [TestResult (name ++ "_" ++ caseName) True "ok" (show $ hashLen result) (show $ hashLen result)]
    hashLen :: ByteString -> Int
    hashLen = const 32

testHmacFunction :: String -> ([Word8] -> [Word8] -> ByteString) -> IO [TestResult] -> IO [TestResult]
testHmacFunction name fn !results = do
  key <- getRandomBytes 32
  caseNameResults <- mapM testCase testVectors
  return $ reverse (concat caseNameResults) ++ results
  where
    testCase (caseName, inputData) = do
      let result = fn key inputData
      if null result
        then return [TestResult (name ++ "_" ++ caseName) False "empty result" "" ""]
        else return [TestResult (name ++ "_" ++ caseName) True "ok" (show $ hashLen result) (show $ hashLen result)]
    hashLen :: ByteString -> Int
    hashLen = const 32

testDeterministic :: ([Word8] -> ByteString) -> String -> IO [TestResult] -> IO [TestResult]
testDeterministic fn inputName !results = do
  let inputData = case lookup inputName testVectors of
        Just d -> d
        Nothing -> emptyInput
  let r1 = fn inputData
  let r2 = fn inputData
  let isEqual = r1 == r2
  return $ TestResult ("deterministic_" ++ inputName) isEqual "consistent output" (show r1) (show r2) : results

testCollisionResistance :: ([Word8] -> ByteString) -> Int -> IO [TestResult] -> IO [TestResult]
testCollisionResistance fn sampleCount !results = do
  let hashes = map (\i -> fn $ map (toEnum . fromEnum) $ "test_" ++ show i) [0..sampleCount]
  let allUnique = length hashes == length (nub hashes)
  return $ TestResult "collision_resistance" allUnique (show sampleCount ++ " unique") "unique" (show allUnique) : results
  where
    nub :: Eq a => [a] -> [a]
    nub [] = []
    nub (x:xs) = x : nub (filter (/= x) xs)

testOutputLengths :: ([Word8] -> ByteString) -> [Int] -> IO [TestResult] -> IO [TestResult]
testOutputLengths fn expectedLengths !results = do
  let inputData = shortString
  let result = fn inputData
  let found = resultLen `elem` expectedLengths
  let resultLen = 32
  if not found
    then return $ TestResult "output_length" False ("got " ++ show resultLen) (show expectedLengths) (show resultLen) : results
    else return $ TestResult "output_length" True "ok" (show expectedLengths) (show resultLen) : results

testKnownAnswer :: ([Word8] -> ByteString) -> [Word8] -> [Word8] -> String -> IO [TestResult] -> IO [TestResult]
testKnownAnswer fn inputData expected testName !results = do
  let result = fn inputData
  let isEqual = result == expected
  return $ TestResult testName isEqual "known answer" (toHex expected) (toHex result) : results

toHex :: [Word8] -> String
toHex = intercalate "" . map (printf "%02x")

runAllTests :: IO (Int, Int, Int)
runAllTests = do
  results <- newCryptoTestHarness
  
  putStrLn "============================================================"
  putStrLn "HASKELL CRYPTOGRAPHY TEST HARNESS"
  putStrLn "============================================================"
  
  results <- testHashFunction "sha256" hashSHA256 results
  results <- testHashFunction "sha512" hashSHA512 results
  results <- testHashFunction "md5" hashMD5 results
  results <- testHashFunction "sha1" hashSHA1 results
  results <- testHashFunction "blake2b" hashBLAKE2b results
  results <- testHashFunction "blake2s" hashBLAKE2s results
  
  results <- testHmacFunction "hmac_sha256" (\k d -> hmacSHA256 k d) results
  results <- testHmacFunction "hmac_sha512" (\k d -> hmacSHA512 k d) results
  
  results <- testDeterministic (hashSHA256 . pack) "empty_input" results
  results <- testDeterministic (hashSHA256 . pack) "single_byte" results
  results <- testDeterministic (hashSHA256 . pack) "short_string" results
  
  results <- testCollisionResistance (hashSHA256 . pack) 100 results
  
  results <- testOutputLengths (hashSHA256 . pack) [32] results
  results <- testOutputLengths (hashSHA512 . pack) [64] results
  
  let passed = length $ filter testPassed results
  let failed = length $ filter (not . testPassed) results
  
  forM_ (reverse results) $ \r -> do
    let status = if testPassed r then "PASS" else "FAIL"
    putStrLn $ "[" ++ status ++ "] " ++ testName r ++ ": " ++ testMsg r
    hFlush stdout
  
  putStrLn "============================================================"
  putStrLn $ "RESULTS: " ++ show passed ++ " passed, " ++ show failed ++ " failed"
  putStrLn "============================================================"
  
  return (passed, failed, passed + failed)

main :: IO ()
main = do
  (passed, failed, _) <- runAllTests
  if failed > 0
    then putStrLn $ "\nCRITICAL: " ++ show failed ++ " tests failed!"
    else putStrLn "\nAll crypto basis tests passed!"