//    Copyright (c) 2016, RED When Excited
//    All rights reserved.
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions are met:
//
//    * Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
//    * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

/// To be implemented by any error that is expected to be meaningful to a user looking at parsing results
public protocol HumanConsumableError {
    /// The human readable message
    var message : String {get}
    /// The range in the source scalars that the error was generated against
    var range : Range<String.UnicodeScalarView.Index> {get}
}

/**
 Any error generated by the underlying parsing engine. These are generally replaced if they occur by any @error annotations.
 */
public enum LanguageError : Error, HumanConsumableError, CustomStringConvertible, Equatable {
    /// An error in scanning (for example illegal scanning range), the index and message to be displayed. This is the lowest level of error
    /// and would normally indicate a defect in OysterKit or an implementation of a `ScanningRule`
    case scanningError(at: Range<String.UnicodeScalarView.Index>, message:String)
    
    /// An error in parsing
    case parsingError(at: Range<String.UnicodeScalarView.Index>, message:String)
    
    /// An error in the semantics of the grammar
    case semanticError(at: Range<String.UnicodeScalarView.Index>, referencing: Range<String.UnicodeScalarView.Index>?, message:String)
    
    /// A warning, that can be ignored
    case warning(at: Range<String.UnicodeScalarView.Index>, message:String)
    
    /// The range of the error in the original source scalars
    public var range : Range<String.UnicodeScalarView.Index> {
        switch self {
        case .parsingError(let range, _), .semanticError(let range, _, _), .scanningError(let range, _), .warning(let range, _):
            return range
        }
    }
    
    /// The human readable error message
    public var message : String {
        switch self {
        case .parsingError(_, let message), .semanticError(_, _, let message), .scanningError(_, let message), .warning(_, let message):
            return message
        }
    }
    
    /// A human readable description of the error
    public var description: String{
        switch self {
        case .parsingError(let range, let message), .semanticError(let range, _, let message), .scanningError(let range, let message), .warning(let range, let message):
            return "\(message) from \(range.lowerBound.encodedOffset) to \(range.upperBound.encodedOffset)"
        }
    }
    
    /**
     Determine if one error is exactly the same as another. The range and message must be `==` to each other
     
     - Parameter lhs: The first error
     - Parameter rhs: The second error
     - Returns: `true` If the two errors are exactly the same or `false` otherwise.
    */
    public static func ==(lhs:LanguageError, rhs:LanguageError)->Bool{
       return lhs.range == rhs.range && lhs.message == rhs.message
    }
}

/**
 Utility functions
 */
public extension HumanConsumableError {
    /**
     Provides a formatted version of the error message suitable for printing in a fixed width font, with a pointer highlighting the
     location of the error
     
     - Parameter in: The original source that was being parsed
     - Returns: A formatted `String` with a human readable and helpful message
    */
    func formattedErrorMessage(`in` input:String)->String{
        
        func occurencesOf(_ character: Character, `in` asString:String)->(count:Int,lastFound:String.Index) {
            var lastInstance = asString.startIndex
            var count = 0
            
            for (offset,element) in asString.enumerated() {
                if character == element {
                    count += 1
                    
                    lastInstance = asString.index(asString.startIndex, offsetBy: offset)
                }
            }
            
            return (count, lastInstance)
        }
        
        let errorIndex : String.Index
        
        
        if range.lowerBound >= input.endIndex {
            errorIndex = input.index(before: input.endIndex)
        } else {
            errorIndex = range.lowerBound
        }
        
        let occurences      = occurencesOf("\n", in: String(input[input.startIndex..<errorIndex]))
        
        let offsetInLine    = input.distance(from: occurences.lastFound, to: errorIndex)
        let inputAfterError = input[input.index(after:errorIndex)..<input.endIndex]
        let nextCharacter   = inputAfterError.index(of: "\n") ?? inputAfterError.endIndex
        let errorLine       = String(input[occurences.lastFound..<nextCharacter])
        let prefix          = "\(message) at line \(occurences.count), column \(offsetInLine): "
        
        let pointerLine     = String(repeating:" ", count: prefix.count+offsetInLine)+"^"
        
        return "\(prefix)\(errorLine)\n\(pointerLine)"
    }
}

/**
 A language stores a set of grammar rules that can be used to parse `String`s. Extensions provide additional methods (such as parsing) that operate on these rules.
 */
public protocol Language{
    /// The rules in the `Language`'s grammar
    var  grammar : [Rule] {get}
}

/// Extensions to an array where the elements are `Rule`s
public extension Array where Element == Rule {
    /// The language for the `[Rule]`
    public var language : Language {
        return Parser(grammar: self)
    }
}
