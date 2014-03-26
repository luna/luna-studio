{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE OverloadedStrings         #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}

module Text.Doc.Parser where

import           Control.Applicative
import           Data.Either                   (rights)
import           Data.Monoid
import           Data.String                   as S
import           Prelude                       hiding ((++))
import qualified Text.Blaze.Html.Renderer.Utf8 as HTML
import           Text.Blaze.Html5              ((!))
import qualified Text.Blaze.Html5              as HTML
import qualified Text.Blaze.Html5.Attributes   as Attr
import           Text.Parsec                   hiding (many, optional, parse, (<|>))
import qualified Text.Parsec                   as Parsec

import qualified Text.Doc.Lexer as L
import           Text.Doc.Utils

-- HEADINGS
pHeadings = choice [ try pH1, try pH2, pH3 ] <?> "heading"

anchor text = fromString $ [x | x <- text, x /= ' ']

pAddAnchor :: String -> HTML.Html
pAddAnchor headingText = do-- 
                            (HTML.a ! Attr.name (anchor headingText) $ HTML.toHtml ("" :: String))
                            HTML.toHtml (headingText :: String)

pH1 = HTML.h1 . pAddAnchor <$> surround L.pH1 L.headingTxt
pH2 = HTML.h2 . pAddAnchor <$> surround L.pH2 L.headingTxt
pH3 = HTML.h3 . pAddAnchor <$> surround L.pH3 L.headingTxt

-- FORMATTED TEXT
pFormattedText = choice [ try pTextBoldItalic, try pTextItalic, pTextBold ] <?> "formatted text"

pTextBoldItalic = HTML.b . HTML.i . HTML.toHtml <$> surround L.pTextBoldItalic  L.formattedText
pTextItalic     = HTML.i . HTML.toHtml          <$> surround L.pTextItalic      L.formattedText
pTextBold       = HTML.b . HTML.toHtml          <$> surround L.pTextBold        L.formattedText

-- CODE
pCode = choice [ try pCodeSnippet, pCodeInline ] <?> "code snippet"

pBlockLine  p   = p *> (many $ noneOf "\n\r") <* L.eol
pBlock      p   = unlines  <$> (L.eol *> many1 p)

pCodeLine       = pBlockLine L.pCodeLineBegin
pCodeSnippet    = generateBlockCode <$> pBlock pCodeLine
pCodeInline     = generateInlineCode <$> (surround L.pCodeInline L.inlineCode)

generateInlineCode content = HTML.span ! Attr.style "font-family: monospace;" $ HTML.toHtml content
generateBlockCode content = HTML.pre ! Attr.class_ "prettyprint" $ HTML.toHtml content

-- QUOTE
pQuote = try pQuoteBlock <?> "quote"

pQuoteLine  = pBlockLine L.pQuoteLineBegin
pQuoteBlock = HTML.blockquote . HTML.toHtml <$> pBlock pQuoteLine

-- HR
pHR = HTML.hr <$ L.pHR <?> "hr"

-- LISTS
pLists = choice [ try pListBullet, try pListOrdered ] <?> "list"

pList p li      = p <$> (foldr (++) mempty <$> (map (HTML.li . HTML.toHtml) <$> (L.eol *> many1 (pBlockLine li))))

pListBullet     = pList HTML.ul L.pUlLiBegin
pListOrdered    = pList HTML.ol L.pOlLiBegin

-- LINKS AND IMAGES
pLink = choice [ try pImage, try pAddress', try pAddress ]

pAddress    = (\s -> generateLink s s) <$> url
              where url = ( (++) <$> L.pLinkBegin <*> many L.pNotWhitespace )
pAddress'   = generateLink <$> content <*> url
              where content = between L.pLinkContentBegin L.pLinkContentEnd L.pLinkContent
                    url     = between L.pLinkAddrBegin L.pLinkAddrEnd L.pLinkAddr
pImage      = generateImage <$> content <*> url
              where content = L.pImageBegin *> between L.pLinkContentBegin L.pLinkContentEnd L.pLinkContent
                    url     = between L.pLinkAddrBegin L.pLinkAddrEnd L.pLinkAddr

generateLink content addr = HTML.a ! Attr.href (fromString addr) $ (HTML.toHtml content)
generateImage alt addr    = HTML.img ! Attr.src (fromString addr) ! Attr.alt (fromString alt)

-- ALL
pElement = choice [ pHeadings
                  , pFormattedText
                  , pCode
                  , pQuote
                  , try pHR
                  , pLists
                  , pLink
                  ]

pToken = try pElement
       <|> ((HTML.toHtml . (:[])) <$> anyChar)

pProgram = foldr (++) mempty <$> many pToken <* many(L.eol <* L.pSpaces) <* eof

-- add html structure and js scripts to highlight code snippets
addJSLibs html = HTML.docTypeHtml $ do
    HTML.head $ do
        HTML.title "Markup"
        HTML.meta ! Attr.httpEquiv "Content-Type" ! Attr.content "text/html; charset=utf-8"
        HTML.script "" ! Attr.type_ "text/javascript" ! Attr.src "https://google-code-prettify.googlecode.com/svn/loader/run_prettify.js"
        HTML.link ! Attr.type_ "text/css" ! Attr.rel "stylesheet" ! Attr.href "libs/markup/include/prettify/prettify.css"
    HTML.body html

parse markup = let
                   parsed = rights [Parsec.runParser pProgram (0::Int) "Flowbox Markup Parser" markup]
                   parsedWithJSLibs = fmap addJSLibs parsed
                   [content] = fmap (HTML.renderHtml) parsedWithJSLibs
               in content
