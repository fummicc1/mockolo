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

import Algorithms

func handleImports(pathToDeclsMap: TopLevelDeclMap,
                   customImports: [String]?,
                   excludeImports: [String]?,
                   testableImports: [String]?,
                   relevantPaths: [String]) -> String {
    var topLevelImports: [Import] = []
    var conditionalBlocks: [IfConfigBlock] = []

    for (path, decls) in pathToDeclsMap {
        guard relevantPaths.contains(path) else { continue }

        for decl in decls {
            switch decl {
            case .import(let imp):
                topLevelImports.append(imp)
            case .ifConfig(let block):
                conditionalBlocks.append(block)
            case .entity:
                // Entities are rendered by `renderTemplates`, not here.
                continue
            }
        }
    }

    // Conditional import blocks are emitted in source-appearance order so the
    // generated output matches what a human reader would expect.
    conditionalBlocks.sort(by: { $0.offset < $1.offset })

    if let customImports {
        topLevelImports.append(contentsOf: customImports.map {
            Import(moduleName: $0)
        })
    }

    var decls: [TopLevelDecl] {
        topLevelImports.map { .import($0) } + conditionalBlocks.map { .ifConfig($0) }
    }

    if let testableImports {
        let usedNames = Set(visitModuleName(decls))
        for name in testableImports {
            if !usedNames.contains(name) {
                topLevelImports.append(Import(moduleName: name).asTestable)
            }
        }
    }

    return renderImportDecls(
        decls,
        excludeImports: excludeImports,
        testableImports: testableImports
    )
}

private func renderImportDecls(
    _ decls: [TopLevelDecl],
    excludeImports: [String]?,
    testableImports: [String]?
) -> String {
    var clauseLines: [String] = []
    var simpleImports: [Import] = []
    func resolveAccumulatedSimpleImports() {
        if !simpleImports.isEmpty {
            clauseLines.append(simpleImports.resolved().lines())
            simpleImports.removeAll(keepingCapacity: true)
        }
    }

    for decl in decls {
        switch decl {
        case .import(var `import`):
            if let excludeImports, excludeImports.contains(`import`.moduleName) {
                continue
            }
            if let testableImports, testableImports.contains(`import`.moduleName) {
                `import` = `import`.asTestable
            }
            simpleImports.append(`import`)
        case .ifConfig(let block):
            // Flush any pending plain imports first so they don't end up
            // inside the conditional block we're about to emit.
            resolveAccumulatedSimpleImports()
            if let rendered = renderIfConfigImports(block, excludeImports: excludeImports, testableImports: testableImports) {
                clauseLines.append(rendered)
            }
        case .entity:
            // Entity decls don't contribute to import output. Skipping them
            // here keeps the renderer for `#if` blocks symmetric across the
            // import and entity paths.
            continue
        }
    }
    resolveAccumulatedSimpleImports()

    return clauseLines.joined(separator: "\n")
}

/// Renders an `#if` block's imports. Returns `nil` if no clause has any
/// import output, so a block that only wraps entities (or only wraps
/// excluded imports) doesn't leak an empty `#if/#endif` skeleton.
private func renderIfConfigImports(
    _ block: IfConfigBlock,
    excludeImports: [String]?,
    testableImports: [String]?
) -> String? {
    var lines: [String] = []
    var hasOutput = false

    for clause in block.clauses {
        let body = renderImportDecls(clause.decls, excludeImports: excludeImports, testableImports: testableImports)
        guard !body.isEmpty else { continue }
        hasOutput = true

        switch clause.condition {
        case .if(let condition):
            lines.append("#if \(condition)")
        case .elseif(let condition):
            lines.append("#elseif \(condition)")
        case .else:
            lines.append("#else")
        }
        lines.append(body)
    }

    guard hasOutput else { return nil }
    lines.append("#endif")
    return lines.joined(separator: "\n")
}

private func visitModuleName(_ decls: [TopLevelDecl]) -> [String] {
    return decls.flatMap { decl -> [String] in
        switch decl {
        case .import(let imp):
            return [imp.moduleName]
        case .ifConfig(let block):
            return visitModuleName(block.clauses.flatMap(\.decls))
        case .entity:
            return []
        }
    }
}
