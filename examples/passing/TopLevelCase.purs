module TopLevelCase where

  import Prelude

  gcd :: Number -> Number -> Number
  gcd 0 x = x
  gcd x 0 = x
  gcd x y | x > y = gcd (x % y) y
  gcd x y = gcd (y % x) x

  guardsTest (x:xs) | x > 0 = guardsTest xs
  guardsTest xs = xs

  data A = A

  parseTest A 0 = 0
    
module Main where

main = Debug.Trace.trace "Done"
