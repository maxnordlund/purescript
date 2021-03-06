module MonadTest where

  type Monad m = { return :: forall a. a -> m a
		 , bind :: forall a b. m a -> (a -> m b) -> m b }

  data Id a = Id a

  id :: Monad Id
  id = { return : Id
       , bind : \ma f -> case ma of Id a -> f a }

  data Maybe a = Nothing | Just a

  maybe :: Monad Maybe
  maybe = { return : Just
	  , bind : \ma f -> case ma of
	      Nothing -> Nothing
	      Just a -> f a 
	  }

  test :: forall m. Monad m -> m Number
  test = \m -> m.bind (m.return 1) (\n1 ->
		 m.bind (m.return "Test") (\n2 -> 
		   m.return n1))

  test1 = test id

  test2 = test maybe
    
module Main where

main = Debug.Trace.trace "Done"
