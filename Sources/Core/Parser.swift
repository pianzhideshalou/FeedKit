//
//  Parser.swift
//
//  Copyright (c) 2016 Nuno Manuel Dias
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

/**
 
 The actual engine behind the `FeedKit` framework. `Parser` handles
 the parsing of RSS and Atom feeds. It is an `XMLParserDelegate` of
 itself.
 
 */
class Parser: XMLParser, XMLParserDelegate {
    
    
    /**
     
     The Feed Type currently being parsed. The Initial value of this variable
     is unknown until a recognizable element that matches a feed type is
     found.
     
     */
    var feedType: FeedType?
    
    
    
    /**
     
     The RSS feed model
     
     */
    var rssFeed: RSSFeed?
    
    
    
    /**
     
     The Atom feed model
     
     */
    var atomFeed: AtomFeed?
    
    
    /**
     
     The current path along the XML's DOM elements. Path components are
     updated to reflect the current XML element being parsed.
     e.g. "/rss/channel/title" mean it's currently parsing the channels
     `<title>` element.
     
     */
    fileprivate var currentXMLDOMPath: URL = URL(string: "/")!
    
    
    /**
     
     Initializes a parser with the XML contents encapsulated in a given
     data object.
     
     The sole purpose of overriding this method is to become it's own
     delegate, and thus, hanlde the parsing logic
     
     */
    override init(data: Data) {
        super.init(data: data)
        self.delegate = self
    }
    
    
    
    /**
     
     Starts parsing the feed.
     
     */
    func parseFeed() -> Result {
        
        self.parse()
        
        if let error = parsingError {
            return Result.failure(error)
        }
        
        guard let feedType = self.feedType else {
            return Result.failure(ParserError.feedNotFound.value)
        }
        
        switch feedType {
            
        case .Atom:
            return Result.atom(self.atomFeed!)
            
        case .RSS1, .RSS2:
            return Result.rss(self.rssFeed!)
            
        }
        
    }
    
    
    /**
     
     Redirects characters found between XML elements to their proper model
     mappers based on the `currentXMLDOMPath`
     
     */
    fileprivate func mapCharacters(_ string: String) {
        
        guard let feedType = self.feedType else { return }
        
        switch feedType {
            
        case .Atom:
            
            if let path = AtomPath(rawValue: self.currentXMLDOMPath.absoluteString) {
                self.atomFeed?.map(characters: string, forPath: path)
            }
            
        case .RSS1, .RSS2:
            
            if let path = RSSPath(rawValue: self.currentXMLDOMPath.absoluteString) {
                self.rssFeed?.map(string: string, forPath: path)
            }
            
        }
        
    }
    
    var parsingError: NSError?
    
    
}


// MARK: - XMLParser delegate


extension Parser {
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        
        // Update the current path along the XML's DOM elements by appending the new component with `elementName`
        self.currentXMLDOMPath = self.currentXMLDOMPath.appendingPathComponent(elementName)
        
        // Get the feed type from the element, if it hasn't been done yet
        guard let feedType = self.feedType else {
            self.feedType = FeedType(rawValue: elementName)
            return
        }
        
        switch feedType {
            
        case .Atom:
            
            if  self.atomFeed == nil {
                self.atomFeed = AtomFeed()
            }
            
            if let path = AtomPath(rawValue: self.currentXMLDOMPath.absoluteString) {
                self.atomFeed?.map(attributes: attributeDict, forPath: path)
            }
            
        case .RSS1, .RSS2:
            
            if  self.rssFeed == nil {
                self.rssFeed = RSSFeed()
            }
            
            if let path = RSSPath(rawValue: self.currentXMLDOMPath.absoluteString) {
                self.rssFeed?.map(attributes: attributeDict, forPath: path)
            }
            
        }
        
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        // Update the current path along the XML's DOM elements by deleting last component
        self.currentXMLDOMPath = self.currentXMLDOMPath.deletingLastPathComponent()
        
    }
    
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        
        guard let string = String(data: CDATABlock, encoding: .utf8) else {
            self.abortParsing()
            self.parsingError = ParserError.feedCDATABlockEncodingError(path: self.currentXMLDOMPath.absoluteString).value
            return
        }
        
        self.mapCharacters(string)
        
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        self.mapCharacters(string)
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parsingError = parseError as NSError
    }
    
}
