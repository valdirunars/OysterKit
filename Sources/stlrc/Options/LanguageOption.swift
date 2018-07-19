//
//  StlrOptions.swift
//  OysterKitPackageDescription
//
//  Created by Swift Studies on 08/12/2017.
//

import Foundation
import OysterKit
import STLR

class LanguageOption : Option, IndexableParameterized {
    typealias ParameterIndexType    = Parameters
    
    /**
     Parameters
     */
    public enum Parameters : Int, ParameterIndex {
        case language = 0
        
        public var parameter: Parameter{
            switch self {
            case .language:
                return Language().one(optional: false)
            }
        }
        
        public static var all: [Parameter]{
            return [
                Parameters.language.parameter
            ]
        }
    }
    
    public struct Language : ParameterType{
        enum Supported : String{
            case swift
            case swiftIR

            var fileExtension : String {
                switch self {
                case .swift:
                    return rawValue
                case .swiftIR:
                    return "swift"
                }
            }
            
            func operations(in scope:STLRScope, for grammarName:String) throws ->[STLR.Operation]? {
                switch self {
                case .swift:
                    return nil
                case .swiftIR:
                    return try SwiftStructure.generate(for: scope, grammar: grammarName)
                }
            }
            
            
            func generate(grammarName: String, from stlrParser:STLRParser, optimize:Bool, outputTo:String) throws {
                if optimize {
                    STLRScope.register(optimizer: InlineIdentifierOptimization())
                    STLRScope.register(optimizer: CharacterSetOnlyChoiceOptimizer())
                } else {
                    STLRScope.removeAllOptimizations()
                }
                
                stlrParser.ast.optimize()
                
                /// Use operation based generators
                if let operations = try operations(in: stlrParser.ast, for: grammarName) {
                    let workingDirectory = URL(fileURLWithPath: outputTo).deletingLastPathComponent().path
                    for operation in operations{
                        do {
                            try operation.perform(in: URL(fileURLWithPath: workingDirectory))
                        } catch {
                            if let error = error as? OperationError {
                                print(error.message)
                                if error.terminate {
                                    exit(EXIT_FAILURE)
                                }
                            } else {
                                print(error.localizedDescription)
                                throw error
                            }
                        }
                    }
                } else {
                    switch self {
                    case .swift:
                        let generatedLanguage = stlrParser.ast.swift(grammar: grammarName)
                        if let generatedLanguage = generatedLanguage {
                            try generatedLanguage.write(toFile: outputTo, atomically: true, encoding: String.Encoding.utf8)
                        } else {
                            print("Couldn't generate language".color(.red))
                        }
                    default:
                        throw OperationError.error(message: "Language did not produce operations", exitCode: Int(EXIT_FAILURE))
                    }
                }
                
                
            }
            
        }
        
        public var name = "Language"
        
        public func transform(_ argumentValue: String) -> Any? {
            return Supported(rawValue: argumentValue)
        }
    }
    
    init(){
        super.init(shortForm: "l", longForm: "language", description: "The language to generate", parameterDefinition: Parameters.all, required: false)
    }

}



