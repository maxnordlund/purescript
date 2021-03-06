-----------------------------------------------------------------------------
--
-- Module      :  Language.PureScript.Parser.Values
-- Copyright   :  (c) Phil Freeman 2013
-- License     :  MIT
--
-- Maintainer  :  Phil Freeman <paf31@cantab.net>
-- Stability   :  experimental
-- Portability :
--
-- |
-- Parsers for values, statements, binders and guards
--
-----------------------------------------------------------------------------

module Language.PureScript.Parser.Values (
    parseValue,
    parseGuard,
    parseBinder,
    parseBinderNoParens,
) where

import Control.Applicative

import Language.PureScript.Values
import Language.PureScript.Parser.State
import Language.PureScript.Parser.Types

import Text.Parsec.Expr

import qualified Language.PureScript.Parser.Common as C
import qualified Text.Parsec as P

booleanLiteral :: P.Parsec String ParseState Bool
booleanLiteral = (C.reserved "true" >> return True) P.<|> (C.reserved "false" >> return False)

parseNumericLiteral :: P.Parsec String ParseState Value
parseNumericLiteral = NumericLiteral <$> C.integerOrFloat

parseStringLiteral :: P.Parsec String ParseState Value
parseStringLiteral = StringLiteral <$> C.stringLiteral

parseBooleanLiteral :: P.Parsec String ParseState Value
parseBooleanLiteral = BooleanLiteral <$> booleanLiteral

parseArrayLiteral :: P.Parsec String ParseState Value
parseArrayLiteral = ArrayLiteral <$> C.squares (C.commaSep parseValue)

parseObjectLiteral :: P.Parsec String ParseState Value
parseObjectLiteral = ObjectLiteral <$> C.braces (C.commaSep parseIdentifierAndValue)

parseIdentifierAndValue :: P.Parsec String ParseState (String, Value)
parseIdentifierAndValue = (,) <$> (C.indented *> C.identifier <* C.indented <* C.colon)
                              <*> (C.indented *> parseValue)

parseAbs :: P.Parsec String ParseState Value
parseAbs = do
  C.reservedOp "\\"
  args <- P.many1 (C.indented *> (Abs <$> (Left <$> P.try C.parseIdent <|> Right <$> parseBinderNoParens)))
  C.indented *> C.reservedOp "->"
  value <- parseValue
  return $ toFunction args value
  where
  toFunction :: [Value -> Value] -> Value -> Value
  toFunction args value = foldr ($) value args

parseVar :: P.Parsec String ParseState Value
parseVar = Var <$> C.parseQualified C.parseIdent

parseConstructor :: P.Parsec String ParseState Value
parseConstructor = Constructor <$> C.parseQualified C.properName

parseCase :: P.Parsec String ParseState Value
parseCase = Case <$> P.between (P.try (C.reserved "case")) (C.indented *> C.reserved "of") (return <$> parseValue)
                 <*> (C.indented *> C.mark (P.many (C.same *> C.mark parseCaseAlternative)))

parseCaseAlternative :: P.Parsec String ParseState CaseAlternative
parseCaseAlternative = CaseAlternative <$> (return <$> parseBinder)
                                       <*> P.optionMaybe parseGuard
                                       <*> (C.indented *> C.reservedOp "->" *> parseValue)
                                       P.<?> "case alternative"

parseIfThenElse :: P.Parsec String ParseState Value
parseIfThenElse = IfThenElse <$> (P.try (C.reserved "if") *> C.indented *> parseValue)
                             <*> (C.indented *> C.reserved "then" *> C.indented *> parseValue)
                             <*> (C.indented *> C.reserved "else" *> C.indented *> parseValue)

parseLet :: P.Parsec String ParseState Value
parseLet = do
  C.reserved "let"
  C.indented
  binder <- P.try (Right <$> ((,) <$> C.parseIdent <*> P.many (Left <$> P.try C.parseIdent <|> Right <$> parseBinderNoParens)))
            <|> (Left <$> parseBinder)
  C.indented
  C.reservedOp "="
  C.indented
  value <- parseValue
  C.indented
  C.reserved "in"
  result <- parseValue
  return $ Let binder value result

parseValueAtom :: P.Parsec String ParseState Value
parseValueAtom = P.choice
            [ P.try parseNumericLiteral
            , P.try parseStringLiteral
            , P.try parseBooleanLiteral
            , parseArrayLiteral
            , P.try parseObjectLiteral
            , parseAbs
            , P.try parseConstructor
            , P.try parseVar
            , parseCase
            , parseIfThenElse
            , parseDo
            , parseLet
            , Parens <$> C.parens parseValue ]

parsePropertyUpdate :: P.Parsec String ParseState (String, Value)
parsePropertyUpdate = do
  name <- C.lexeme C.identifier
  _ <- C.lexeme $ C.indented *> P.char '='
  value <- C.indented *> parseValue
  return (name, value)

parseAccessor :: Value -> P.Parsec String ParseState Value
parseAccessor (Constructor _) = P.unexpected "constructor"
parseAccessor obj = P.try $ Accessor <$> (C.indented *> C.dot *> P.notFollowedBy C.opLetter *> C.indented *> C.identifier) <*> pure obj

parseDo :: P.Parsec String ParseState Value
parseDo = do
  C.reserved "do"
  C.indented
  Do <$> C.mark (P.many (C.same *> C.mark parseDoNotationElement))

parseDoNotationLet :: P.Parsec String ParseState DoNotationElement
parseDoNotationLet = DoNotationLet <$> (C.reserved "let" *> C.indented *> parseBinder)
                                   <*> (C.indented *> C.reservedOp "=" *> parseValue)

parseDoNotationBind :: P.Parsec String ParseState DoNotationElement
parseDoNotationBind = DoNotationBind <$> parseBinder <*> (C.indented *> C.reservedOp "<-" *> parseValue)

parseDoNotationElement :: P.Parsec String ParseState DoNotationElement
parseDoNotationElement = P.choice
            [ P.try parseDoNotationBind
            , parseDoNotationLet
            , P.try (DoNotationValue <$> parseValue) ]

-- |
-- Parse a value
--
parseValue :: P.Parsec String ParseState Value
parseValue =
  (buildExpressionParser operators
   . C.buildPostfixParser postfixTable2
   $ indexersAndAccessors) P.<?> "expression"
  where
  indexersAndAccessors = C.buildPostfixParser postfixTable1 parseValueAtom
  postfixTable1 = [ parseAccessor
                  , \v -> P.try $ flip ObjectUpdate <$> (C.indented *> C.braces (C.commaSep1 (C.indented *> parsePropertyUpdate))) <*> pure v ]
  postfixTable2 = [ \v -> P.try (flip App <$> (C.indented *> indexersAndAccessors)) <*> pure v
                  , \v -> flip (TypedValue True) <$> (P.try (C.lexeme (C.indented *> P.string "::")) *> parsePolyType) <*> pure v
                  ]
  operators = [ [ Infix (C.lexeme (P.try (C.indented *> C.parseIdentInfix P.<?> "operator") >>= \ident ->
                    return (BinaryNoParens ident))) AssocRight ]
              ]

parseStringBinder :: P.Parsec String ParseState Binder
parseStringBinder = StringBinder <$> C.stringLiteral

parseBooleanBinder :: P.Parsec String ParseState Binder
parseBooleanBinder = BooleanBinder <$> booleanLiteral

parseNumberBinder :: P.Parsec String ParseState Binder
parseNumberBinder = NumberBinder <$> C.integerOrFloat

parseVarBinder :: P.Parsec String ParseState Binder
parseVarBinder = VarBinder <$> C.parseIdent

parseNullaryConstructorBinder :: P.Parsec String ParseState Binder
parseNullaryConstructorBinder = ConstructorBinder <$> C.lexeme (C.parseQualified C.properName) <*> pure []

parseConstructorBinder :: P.Parsec String ParseState Binder
parseConstructorBinder = ConstructorBinder <$> C.lexeme (C.parseQualified C.properName) <*> many (C.indented *> parseBinderNoParens)

parseObjectBinder :: P.Parsec String ParseState Binder
parseObjectBinder = ObjectBinder <$> C.braces (C.commaSep (C.indented *> parseIdentifierAndBinder))

parseArrayBinder :: P.Parsec String ParseState Binder
parseArrayBinder = C.squares $ ArrayBinder <$> C.commaSep (C.indented *> parseBinder)

parseNamedBinder :: P.Parsec String ParseState Binder
parseNamedBinder = NamedBinder <$> (C.parseIdent <* C.indented <* C.lexeme (P.char '@'))
                               <*> (C.indented *> parseBinder)

parseNullBinder :: P.Parsec String ParseState Binder
parseNullBinder = C.lexeme (P.char '_') *> P.notFollowedBy C.identLetter *> return NullBinder

parseIdentifierAndBinder :: P.Parsec String ParseState (String, Binder)
parseIdentifierAndBinder = do
  name <- C.lexeme C.identifier
  _ <- C.lexeme $ C.indented *> P.char '='
  binder <- C.indented *> parseBinder
  return (name, binder)

-- |
-- Parse a binder
--
parseBinder :: P.Parsec String ParseState Binder
parseBinder = buildExpressionParser operators parseBinderAtom P.<?> "expression"
  where
  operators = [ [ Infix ( C.lexeme (P.try $ C.indented *> C.reservedOp ":") >> return ConsBinder) AssocRight ] ]
  parseBinderAtom :: P.Parsec String ParseState Binder
  parseBinderAtom = P.choice (map P.try
                    [ parseNullBinder
                    , parseStringBinder
                    , parseBooleanBinder
                    , parseNumberBinder
                    , parseNamedBinder
                    , parseVarBinder
                    , parseConstructorBinder
                    , parseObjectBinder
                    , parseArrayBinder
                    , C.parens parseBinder ]) P.<?> "binder"

-- |
-- Parse a binder as it would appear in a top level declaration
--
parseBinderNoParens :: P.Parsec String ParseState Binder
parseBinderNoParens = P.choice (map P.try
                  [ parseNullBinder
                  , parseStringBinder
                  , parseBooleanBinder
                  , parseNumberBinder
                  , parseNamedBinder
                  , parseVarBinder
                  , parseNullaryConstructorBinder
                  , parseObjectBinder
                  , parseArrayBinder
                  , C.parens parseBinder ]) P.<?> "binder"
-- |
-- Parse a guard
--
parseGuard :: P.Parsec String ParseState Guard
parseGuard = C.indented *> C.pipe *> C.indented *> parseValue

