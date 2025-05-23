//
//  Copyright (c) 2018. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import CoreFoundation
import Foundation

enum InputError: Error {
    case annotationError
    case sourceFilesError
}

/// Performs end to end mock generation flow
@discardableResult
public func generate(sourceDirs: [String],
                     sourceFiles: [String],
                     parser: SourceParser,
                     exclusionSuffixes: [String],
                     mockFilePaths: [String]?,
                     annotation: String,
                     header: String?,
                     macro: String?,
                     declType: FindTargetDeclType,
                     useTemplateFunc: Bool,
                     allowSetCallCount: Bool,
                     enableFuncArgsHistory: Bool,
                     disableCombineDefaultValues: Bool,
                     mockFinal: Bool,
                     testableImports: [String],
                     customImports: [String],
                     excludeImports: [String],
                     to outputFilePath: String,
                     loggingLevel: Int,
                     concurrencyLimit: Int?) throws -> String {
    guard sourceDirs.count > 0 || sourceFiles.count > 0 else {
        log("Source files or directories do not exist", level: .error)
        throw InputError.sourceFilesError
    }
    
    scanConcurrencyLimit = concurrencyLimit
    minLogLevel = loggingLevel
    var candidates = [(String, Int64)]()
    var resolvedEntities = [ResolvedEntity]()
    var parentMocks = [String: Entity]()
    var protocolMap = [String: Entity]()
    var annotatedProtocolMap = [String: Entity]()
    var pathToImportsMap = ImportMap()
    var relevantPaths = [String]()

    signpost_begin(name: "Process input")
    let t0 = CFAbsoluteTimeGetCurrent()
    log("Process input mock files...", level: .info)
    if let mockFilePaths = mockFilePaths, !mockFilePaths.isEmpty {
        parser.parseProcessedDecls(mockFilePaths, fileMacro: macro) { (elements, imports) in
                                    elements.forEach { element in
                                        parentMocks[element.entityNode.nameText] = element
                                    }
                                    
                                    if let imports = imports {
                                        for (path, importMap) in imports {
                                            pathToImportsMap[path] = importMap
                                        }
                                    }
        }
    }
    signpost_end(name: "Process input")
    let t1 = CFAbsoluteTimeGetCurrent()
    log("Took", t1-t0, level: .verbose)
    
    signpost_begin(name: "Generate protocol map")
    log("Process source files and generate an annotated/protocol map...", level: .info)
    let paths = !sourceDirs.isEmpty ? sourceDirs : sourceFiles
    let isDirs = !sourceDirs.isEmpty
    parser.parseDecls(paths,
                      isDirs: isDirs,
                      exclusionSuffixes: exclusionSuffixes,
                      annotation: annotation,
                      fileMacro: macro,
                      declType: declType) { (elements, imports) in
                        elements.forEach { element in
                            protocolMap[element.entityNode.nameText] = element
                            if element.isAnnotated {
                                annotatedProtocolMap[element.entityNode.nameText] = element
                            }
                        }
                        if let imports = imports {
                            for (path, importMap) in imports {
                                pathToImportsMap[path] = importMap
                            }
                        }
    }
    signpost_end(name: "Generate protocol map")
    let t2 = CFAbsoluteTimeGetCurrent()
    log("Took", t2-t1, level: .verbose)
    
    let typeKeyList = [
        parentMocks.compactMap { (key, value) -> String? in
            if value.entityNode.mayHaveGlobalActor {
                return nil
            }
            return key.components(separatedBy: "Mock").first
        },
        annotatedProtocolMap.filter { !$0.value.entityNode.mayHaveGlobalActor }.map(\.key)
    ]
        .flatMap { $0 }
        .map { typeName in
            // nameOverride does not work correctly but it giving up.
            return (typeName, "\(typeName)Mock()")
        }
    SwiftType.customDefaultValueMap = [String: String](typeKeyList, uniquingKeysWith: { $1 })

    signpost_begin(name: "Generate models")
    log("Resolve inheritance and generate unique entity models...", level: .info)
    generateUniqueModels(protocolMap: protocolMap,
                         annotatedProtocolMap: annotatedProtocolMap,
                         inheritanceMap: parentMocks,
                         completion: { container in
                            resolvedEntities.append(container.entity)
                            relevantPaths.append(contentsOf: container.paths)
    })
    signpost_end(name: "Generate models")
    let t3 = CFAbsoluteTimeGetCurrent()
    log("Took", t3-t2, level: .verbose)
    
    signpost_begin(name: "Render models")
    log("Render models with templates...", level: .info)
    renderTemplates(
        entities: resolvedEntities,
        arguments: .init(
            useTemplateFunc: useTemplateFunc,
            allowSetCallCount: allowSetCallCount,
            mockFinal: mockFinal,
            enableFuncArgsHistory: enableFuncArgsHistory,
            disableCombineDefaultValues: disableCombineDefaultValues
        )
    ) { (mockString: String, offset: Int64) in
                        candidates.append((mockString, offset))
    }
    signpost_end(name: "Render models")
    let t4 = CFAbsoluteTimeGetCurrent()
    log("Took", t4-t3, level: .verbose)
     
    signpost_begin(name: "Write results")
    log("Write the mock results and import lines to", outputFilePath, level: .info)

    let needsConcurrencyHelpers = resolvedEntities.contains { $0.requiresSendable }

    let imports = handleImports(pathToImportsMap: pathToImportsMap,
                                customImports: customImports + (needsConcurrencyHelpers ? ["Foundation"] : []),
                                excludeImports: excludeImports,
                                testableImports: testableImports,
                                relevantPaths: relevantPaths)

    var helpers = [String]()
    if needsConcurrencyHelpers {
        helpers.append(applyConcurrencyHelpersTemplate())
    }

    let result = try write(candidates: candidates,
                           header: header,
                           macro: macro,
                           imports: imports,
                           helpers: helpers,
                           to: outputFilePath)
    signpost_end(name: "Write results")
    let t5 = CFAbsoluteTimeGetCurrent()
    log("Took", t5-t4, level: .verbose)
    
    let count = result.components(separatedBy: "\n").count
    log("TOTAL", t5-t0, level: .verbose)
    log("#Protocols = \(protocolMap.count), #Annotated protocols = \(annotatedProtocolMap.count), #Parent mock classes = \(parentMocks.count), #Final mock classes = \(candidates.count), File LoC = \(count)", level: .verbose)
    
    return result
}
