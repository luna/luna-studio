import Luna.Typechecker.Data.Type
import Luna.Typechecker.Data.TVar
import Data.Map.Strict (Map)
import Control.Monad
import Control.Applicative
import qualified Data.Map.Strict as M


type TypesTranslate  = Map TVar TVar
type FieldsTranslate = Map String String


runEquiv :: (AlphaEquiv a) => a -> a -> Bool
runEquiv a b = (\(x,fmab,fmba,ttab,ttba) -> x) $ equiv M.empty M.empty M.empty M.empty a b

class AlphaEquiv a where
    equiv :: FieldsTranslate -> FieldsTranslate -> TypesTranslate -> TypesTranslate -> a -> a -> (Bool, FieldsTranslate, FieldsTranslate, TypesTranslate, TypesTranslate)


instance AlphaEquiv Type where
    equiv fmab fmba ttab ttba (TV a) (TV b)
        | M.lookup a ttab == Just b  && M.lookup b ttba == Just a  = (True, fmab, fmba, ttab, ttba)
        | M.notMember a ttab         && M.notMember b ttba         = (True, fmab, fmba, M.insert a b ttab, M.insert b a ttba)
    equiv fmab fmba ttab ttba (p1 `Fun` p2) (q1 `Fun` q2)
        = let (c1,fmab1,fmba1,ttab1,ttba1) = equiv fmab  fmba ttab  ttba  p1 q1
              (c2,fmab2,fmba2,ttab2,ttba2) = equiv fmab1 fmba1 ttab1 ttba1 p2 q2
           in (c1&&c2, fmab2, fmba2, ttab2, ttba2)
    equiv fmab fmba ttab ttba (Record flds1) (Record flds2) | length flds1 == length flds2
        = foldr merge (True, fmab, fmba, ttab, ttba) (zip flds1 flds2)
      where
        merge _                                      (False, fmab, fmba, ttab, ttba) = (False, fmab, fmba, ttab, ttba)
        merge ((fld1lab, fld1ty), (fld2lab, fld2ty)) (True,  fmab, fmba, ttab, ttba) | M.lookup fld1lab fmab == Just fld2lab && M.lookup fld2lab fmba == Just fld1lab 
                                                                                        = equiv fmab fmba ttab ttba fld1ty fld2ty
                                                                                     | M.notMember fld1lab fmab              && M.notMember fld2lab fmba
                                                                                        = let fmab1 = M.insert fld1lab fld2lab fmab
                                                                                              fmba1 = M.insert fld1lab fld1lab fmab1
                                                                                           in equiv fmab1 fmba1 ttab ttba fld1ty fld2ty
        merge ((fld1lab, fld1ty), (fld2lab, fld2ty)) (True,  fmab, fmba, ttab, ttba) = (False, fmab, fmba, ttab, ttba)
    equiv fmab fmba ttab ttba _ _ = (False, fmab, fmba, ttab, ttba)



ts=[ (True,  (TV$TVar 1),                     (TV$TVar 1)                    )
   , (True,  (TV$TVar 2),                     (TV$TVar 1)                    )


   , (True,  ((TV$TVar 1) `Fun` (TV$TVar 1)), ((TV$TVar 1) `Fun` (TV$TVar 1)))
   , (False, ((TV$TVar 1) `Fun` (TV$TVar 1)), ((TV$TVar 1) `Fun` (TV$TVar 0)))
   , (False, ((TV$TVar 1) `Fun` (TV$TVar 1)), ((TV$TVar 0) `Fun` (TV$TVar 1)))
   , (True,  ((TV$TVar 1) `Fun` (TV$TVar 1)), ((TV$TVar 0) `Fun` (TV$TVar 0)))

   , (False, ((TV$TVar 1) `Fun` (TV$TVar 0)), ((TV$TVar 1) `Fun` (TV$TVar 1)))
   , (True,  ((TV$TVar 1) `Fun` (TV$TVar 0)), ((TV$TVar 1) `Fun` (TV$TVar 0)))
   , (True,  ((TV$TVar 1) `Fun` (TV$TVar 0)), ((TV$TVar 0) `Fun` (TV$TVar 1)))
   , (False, ((TV$TVar 1) `Fun` (TV$TVar 0)), ((TV$TVar 0) `Fun` (TV$TVar 0)))

   , (False, ((TV$TVar 0) `Fun` (TV$TVar 1)), ((TV$TVar 1) `Fun` (TV$TVar 1)))
   , (True,  ((TV$TVar 0) `Fun` (TV$TVar 1)), ((TV$TVar 1) `Fun` (TV$TVar 0)))
   , (True,  ((TV$TVar 0) `Fun` (TV$TVar 1)), ((TV$TVar 0) `Fun` (TV$TVar 1)))
   , (False, ((TV$TVar 0) `Fun` (TV$TVar 1)), ((TV$TVar 0) `Fun` (TV$TVar 0)))

   , (True,  ((TV$TVar 0) `Fun` (TV$TVar 0)), ((TV$TVar 1) `Fun` (TV$TVar 1)))
   , (False, ((TV$TVar 0) `Fun` (TV$TVar 0)), ((TV$TVar 1) `Fun` (TV$TVar 0)))
   , (False, ((TV$TVar 0) `Fun` (TV$TVar 0)), ((TV$TVar 0) `Fun` (TV$TVar 1)))
   , (True,  ((TV$TVar 0) `Fun` (TV$TVar 0)), ((TV$TVar 0) `Fun` (TV$TVar 0)))


   , (True,  ((TV$TVar 8) `Fun` (TV$TVar 8)), ((TV$TVar 1) `Fun` (TV$TVar 1)))
   , (False, ((TV$TVar 8) `Fun` (TV$TVar 8)), ((TV$TVar 1) `Fun` (TV$TVar 0)))
   , (False, ((TV$TVar 8) `Fun` (TV$TVar 8)), ((TV$TVar 0) `Fun` (TV$TVar 1)))
   , (True,  ((TV$TVar 8) `Fun` (TV$TVar 8)), ((TV$TVar 0) `Fun` (TV$TVar 0)))

   , (False, ((TV$TVar 8) `Fun` (TV$TVar 9)), ((TV$TVar 1) `Fun` (TV$TVar 1)))
   , (True,  ((TV$TVar 8) `Fun` (TV$TVar 9)), ((TV$TVar 1) `Fun` (TV$TVar 0)))
   , (True,  ((TV$TVar 8) `Fun` (TV$TVar 9)), ((TV$TVar 0) `Fun` (TV$TVar 1)))
   , (False, ((TV$TVar 8) `Fun` (TV$TVar 9)), ((TV$TVar 0) `Fun` (TV$TVar 0)))

   , (False, ((TV$TVar 9) `Fun` (TV$TVar 8)), ((TV$TVar 1) `Fun` (TV$TVar 1)))
   , (True,  ((TV$TVar 9) `Fun` (TV$TVar 8)), ((TV$TVar 1) `Fun` (TV$TVar 0)))
   , (True,  ((TV$TVar 9) `Fun` (TV$TVar 8)), ((TV$TVar 0) `Fun` (TV$TVar 1)))
   , (False, ((TV$TVar 9) `Fun` (TV$TVar 8)), ((TV$TVar 0) `Fun` (TV$TVar 0)))

   , (True,  ((TV$TVar 9) `Fun` (TV$TVar 9)), ((TV$TVar 1) `Fun` (TV$TVar 1)))
   , (False, ((TV$TVar 9) `Fun` (TV$TVar 9)), ((TV$TVar 1) `Fun` (TV$TVar 0)))
   , (False, ((TV$TVar 9) `Fun` (TV$TVar 9)), ((TV$TVar 0) `Fun` (TV$TVar 1)))
   , (True,  ((TV$TVar 9) `Fun` (TV$TVar 9)), ((TV$TVar 0) `Fun` (TV$TVar 0)))

   , (True,   Record [("a",TV$TVar 0), ("b",TV$TVar 1), ("c",TV$TVar 2)],
              Record [("x",TV$TVar 7), ("y",TV$TVar 8), ("z",TV$TVar 9)])
   , (True,   Record [("a",TV$TVar 0), ("b",TV$TVar 1), ("c",TV$TVar 2)],
              Record [("a",TV$TVar 0), ("b",TV$TVar 1), ("c",TV$TVar 2)])
   , (False,  Record [("a",TV$TVar 0), ("b",TV$TVar 1), ("c",TV$TVar 2)],
              Record [("x",TV$TVar 7)])
   , (False,  Record [("a",TV$TVar 0), ("b",TV$TVar 1), ("c",TV$TVar 2)],
              Record [])

   , (True,   Record [("a",((TV$TVar 8) `Fun` (TV$TVar 9))), ("b",TV$TVar 1), ("c",TV$TVar 2)],
              Record [("x",((TV$TVar 1) `Fun` (TV$TVar 0))), ("y",TV$TVar 8), ("z",TV$TVar 9)])
   
   , (True,   (TV$TVar 8) `Fun` (Record [("a",((TV$TVar 8) `Fun` (TV$TVar 9))), ("b",TV$TVar 1), ("c",TV$TVar 2)]),
              (TV$TVar 1) `Fun` (Record [("x",((TV$TVar 1) `Fun` (TV$TVar 0))), ("y",TV$TVar 8), ("z",TV$TVar 9)]))

   , (True,   (TV$TVar 8) `Fun` (Record [("a",((TV$TVar 8) `Fun` (TV$TVar 9))), ("b",TV$TVar 1), ("c",TV$TVar 2)]) `Fun` (TV$TVar 9),
              (TV$TVar 1) `Fun` (Record [("x",((TV$TVar 1) `Fun` (TV$TVar 0))), ("y",TV$TVar 8), ("z",TV$TVar 9)]) `Fun` (TV$TVar 0))


   , (False,  Record [("a",((TV$TVar 8) `Fun` (TV$TVar 9))), ("b",TV$TVar 1), ("c",TV$TVar 8)],
              Record [("x",((TV$TVar 1) `Fun` (TV$TVar 0))), ("y",TV$TVar 8), ("z",TV$TVar 9)])
   
   , (False,  (TV$TVar 8) `Fun` (Record [("a",((TV$TVar 8) `Fun` (TV$TVar 9))), ("b",TV$TVar 1), ("c",TV$TVar 1)]),
              (TV$TVar 1) `Fun` (Record [("x",((TV$TVar 1) `Fun` (TV$TVar 0))), ("y",TV$TVar 8), ("z",TV$TVar 9)]))

   , (False,  (TV$TVar 8) `Fun` (Record [("a",((TV$TVar 1) `Fun` (TV$TVar 9))), ("b",TV$TVar 1), ("c",TV$TVar 2)]) `Fun` (TV$TVar 9),
              (TV$TVar 1) `Fun` (Record [("x",((TV$TVar 1) `Fun` (TV$TVar 0))), ("y",TV$TVar 8), ("z",TV$TVar 9)]) `Fun` (TV$TVar 0))

   , (True,   (TV$TVar 0) `Fun` (Record [("foo", (TV$TVar 0) `Fun` (TV$TVar 1))]) `Fun` (TV$TVar 1),
              (TV$TVar 0) `Fun` (Record [("foo", (TV$TVar 0) `Fun` (TV$TVar 1))]) `Fun` (TV$TVar 1))
   ]


main = do
  forM ts $ \(e,a,b) -> do
    let r = runEquiv a b
    putStrLn $ show e ++ " =?= " ++ show r ++ (if e == r then "" else ("      ╳:    " ++ show a ++ "    ?    " ++ show b))

