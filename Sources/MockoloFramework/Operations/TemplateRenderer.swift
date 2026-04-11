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

import Foundation

/// Renders models with templates for output.
///
/// Entities whose source declaration appears inside a top-level
/// `#if`/`#elseif`/`#else` block are rendered by walking the
/// `ConditionalImportBlock` tree recursively so that the generated mocks are
/// wrapped in the same compilation directive structure as the source.
/// Standalone entities (not wrapped in any `#if`) are rendered in parallel as
/// before.
func renderTemplates(entities: [ResolvedEntity],
                     conditionalBlocks: [ConditionalImportBlock],
                     arguments: GenerationArguments,
                     completion: @escaping (String, Int64) -> ()) {
    // Collect identities of entities that appear anywhere inside a conditional
    // block so we can skip rendering them as standalone candidates.
    var wrappedIdentities = Set<ObjectIdentifier>()
    for block in conditionalBlocks {
        collectWrappedIdentities(in: block, into: &wrappedIdentities)
    }

    // Index resolved entities by their underlying `Entity` identity so we can
    // look them up while walking a conditional block tree.
    var resolvedByIdentity = [ObjectIdentifier: ResolvedEntity]()
    for resolved in entities {
        resolvedByIdentity[ObjectIdentifier(resolved.entity)] = resolved
    }

    // 1. Render standalone entities in parallel (unchanged behavior).
    scan(entities) { (resolvedEntity, lock) in
        if wrappedIdentities.contains(ObjectIdentifier(resolvedEntity.entity)) {
            return
        }
        let mockModel = resolvedEntity.model()
        if let mockString = mockModel.render(
            context: .init(),
            arguments: arguments
        ), !mockString.isEmpty {
            lock?.lock()
            completion(mockString, mockModel.offset)
            lock?.unlock()
        }
    }

    // 2. Render `#if`-wrapped entities by walking the block tree. Each block
    //    is emitted as a single candidate at the block's source offset, so the
    //    `OutputWriter` places it at the correct file position.
    for block in conditionalBlocks.sorted(by: { $0.offset < $1.offset }) {
        if let rendered = renderConditionalBlock(
            block,
            resolvedByIdentity: resolvedByIdentity,
            arguments: arguments
        ) {
            completion(rendered, block.offset)
        }
    }
}

/// Recursively collects `ObjectIdentifier`s of all entities reachable through
/// a conditional block tree (including nested `#if` blocks).
private func collectWrappedIdentities(in block: ConditionalImportBlock,
                                      into set: inout Set<ObjectIdentifier>) {
    for clause in block.clauses {
        for entity in clause.entities {
            set.insert(ObjectIdentifier(entity))
        }
        for content in clause.contents {
            if case .conditional(let nested) = content {
                collectWrappedIdentities(in: nested, into: &set)
            }
        }
    }
}

/// Renders a conditional block as a string, preserving the
/// `#if`/`#elseif`/`#else`/`#endif` structure of the source. Returns `nil`
/// when the block contains no entities that need to be emitted (i.e. the
/// block is purely for imports and has no mockable declarations inside it).
private func renderConditionalBlock(_ block: ConditionalImportBlock,
                                    resolvedByIdentity: [ObjectIdentifier: ResolvedEntity],
                                    arguments: GenerationArguments) -> String? {
    var clauseChunks = [String]()

    for clause in block.clauses {
        var chunkLines = [String]()

        // Render entities directly declared in this clause.
        for entity in clause.entities {
            guard let resolved = resolvedByIdentity[ObjectIdentifier(entity)] else { continue }
            let mockModel = resolved.model()
            if let mockString = mockModel.render(
                context: .init(),
                arguments: arguments
            ), !mockString.isEmpty {
                chunkLines.append(mockString)
            }
        }

        // Recurse into nested `#if` blocks that are themselves nested inside
        // the current clause (e.g. `#if A \n #if B ... #endif \n #endif`).
        for content in clause.contents {
            if case .conditional(let nested) = content,
               let nestedRendered = renderConditionalBlock(
                nested,
                resolvedByIdentity: resolvedByIdentity,
                arguments: arguments
               ) {
                chunkLines.append(nestedRendered)
            }
        }

        guard !chunkLines.isEmpty else { continue }

        let header: String
        switch clause.type {
        case .if(let condition):
            header = "#if \(condition)"
        case .elseif(let condition):
            header = "#elseif \(condition)"
        case .else:
            header = "#else"
        }

        clauseChunks.append(([header] + chunkLines).joined(separator: "\n"))
    }

    guard !clauseChunks.isEmpty else { return nil }
    return (clauseChunks + ["#endif"]).joined(separator: "\n")
}
