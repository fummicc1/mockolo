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

func renderTemplates(declMap: TopLevelDeclMap,
                     resolvedByName: [String: ResolvedEntity],
                     arguments: GenerationArguments,
                     completion: @escaping (String, Int64) -> ()) {
    scan(Array(declMap.values)) { (decls, lock) in
        for decl in decls {
            // An `#if` block is emitted as a single candidate keyed by the
            // block's own offset. Splitting inner entities into individual
            // candidates would let unrelated standalone entities sort into
            // the middle of the block and break the `#if/#endif` pairing.
            guard let (rendered, offset) = render(decl, resolvedByName: resolvedByName, arguments: arguments) else { continue }
            lock?.lock()
            completion(rendered, offset)
            lock?.unlock()
        }
    }
}

private func render(_ decl: TopLevelDecl,
                    resolvedByName: [String: ResolvedEntity],
                    arguments: GenerationArguments) -> (String, Int64)? {
    switch decl {
    case .import:
        // Imports flow through `handleImports`; the entity renderer ignores
        // them so the same source-order tree can drive both pipelines.
        return nil
    case .entity(let entity):
        return renderEntity(entity, resolvedByName: resolvedByName, arguments: arguments)
    case .ifConfig(let block):
        return renderIfConfig(block, resolvedByName: resolvedByName, arguments: arguments)
    }
}

private func renderEntity(_ entity: Entity,
                          resolvedByName: [String: ResolvedEntity],
                          arguments: GenerationArguments) -> (String, Int64)? {
    // A protocol that's syntactically present but not annotated has no
    // `ResolvedEntity`; returning nil drops it from the output (and lets
    // an enclosing `#if` clause drop with it if it was the only content).
    guard let resolved = resolvedByName[entity.entityNode.nameText] else { return nil }
    let mockModel = resolved.model()
    guard let mockString = mockModel.render(context: .init(), arguments: arguments),
          !mockString.isEmpty else { return nil }
    return (mockString, mockModel.offset)
}

private func renderIfConfig(_ block: IfConfigBlock,
                            resolvedByName: [String: ResolvedEntity],
                            arguments: GenerationArguments) -> (String, Int64)? {
    var lines: [String] = []
    var hasOutput = false

    for clause in block.clauses {
        let body = clause.decls.compactMap { render($0, resolvedByName: resolvedByName, arguments: arguments)?.0 }
        // Skip the directive entirely when the clause body is empty; a
        // dangling `#elseif`/`#else` with no content would be syntactically
        // valid but visually confusing in the generated output.
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
        lines.append(contentsOf: body)
    }

    guard hasOutput else { return nil }
    lines.append("#endif")
    return (lines.joined(separator: "\n"), block.offset)
}
