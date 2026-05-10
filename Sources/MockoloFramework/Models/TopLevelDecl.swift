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

indirect enum TopLevelDecl {
    case `import`(Import)
    case entity(Entity)
    case ifConfig(IfConfigBlock)
}

struct IfConfigBlock {
    struct Clause {
        let condition: IfClauseType
        let decls: [TopLevelDecl]
    }
    let clauses: [Clause]
    let offset: Int64
}

extension Sequence where Element == TopLevelDecl {
    var flatEntities: [Entity] {
        var result = [Entity]()
        for decl in self {
            decl.collectEntities(into: &result)
        }
        return result
    }
}

extension TopLevelDecl {
    fileprivate func collectEntities(into result: inout [Entity]) {
        switch self {
        case .import:
            return
        case .entity(let entity):
            result.append(entity)
        case .ifConfig(let block):
            for clause in block.clauses {
                for decl in clause.decls {
                    decl.collectEntities(into: &result)
                }
            }
        }
    }
}
