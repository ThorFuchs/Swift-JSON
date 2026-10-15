#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Qualify actual-engine DSL domain typing and reproducible compiler scaling experiments."""
import argparse, datetime, hashlib, json, os, pathlib, platform, re, subprocess, sys, time

ROOT = pathlib.Path(__file__).resolve().parents[1]
NEGATIVES = {
    'DefinitionInsideProperties.swift': ('Definition', 'JSONSchemaPropertiesContent'),
    'ElementInsideObject.swift': ('Element', 'JSONValueFieldsContent'),
    'FieldInsideSchema.swift': ('Field', 'JSONSchemaClausesContent'),
    'ImplicitFloatingPoint.swift': ('initializer', 'no exact matches'),
    'PropertyInsideDefinitions.swift': ('Property', 'JSONSchemaDefinitionsContent'),
    'SchemaClauseInsideArray.swift': ('SchemaClause', 'JSONValueElementsContent'),
}
POSITIVE = '''import JSONValueDSL
import JSONSchemaDSL
func authored(_ include: Bool, _ names: [String]) throws {
    _ = try JSONValueDSL.object {
        Field("id", UInt64.max)
        if include { Field("flag", true) } else { Field("other", "value") }
        Field.array("a") { for name in names { Element(name) }; Element.array { Element(1) } }
    }
    _ = try JSONSchemaDSL.document {
        Schema.type(.object)
        Schema.properties { for name in names { Property(name) { Schema.type(.string) } } }
        Schema.definitions { Definition("n") { Schema.type(.integer) } }
        Schema.anyOf { Rule(false); Rule { Schema.type(.object) } }
    }
}
'''
QUALIFIED = '''import JSONValueDSL
import JSONSchemaDSL
enum Field {}; enum Element {}; enum Schema {}; enum Property {}; enum Rule {}; enum Definition {}
func qualifiedDeclarations() throws {
    _ = try JSONValueDSL.object {
        JSONValueDSL.Field("exact", UInt64.max)
        JSONValueDSL.Field.array("items") { JSONValueDSL.Element(1) }
    }
    _ = try JSONSchemaDSL.document {
        JSONSchemaDSL.Schema.type(.object)
        JSONSchemaDSL.Schema.properties {
            JSONSchemaDSL.Property("exact") { JSONSchemaDSL.Schema.type(.integer) }
        }
        JSONSchemaDSL.Schema.definitions {
            JSONSchemaDSL.Definition("accept") { JSONSchemaDSL.Schema.anyOf { JSONSchemaDSL.Rule(true) } }
        }
    }
}
'''


def fixtures():
    result = {}
    for width in (16, 64, 128, 256):
        fields = '\n'.join('Field("f%d", %d)' % (n, n) for n in range(width))
        properties = '\n'.join('Property("f%d") { Schema.type(.string) }' % n for n in range(width))
        result['value-%d' % width] = 'import JSONValueDSL\nfunc fixture() throws -> Int { let value = try JSONValueDSL.object {\n' + fields + '\n}; return value.objectValue!.count }\n'
        result['schema-%d' % width] = 'import JSONSchemaDSL\nfunc fixture() throws -> Int { let schema = try JSONSchemaDSL.document { Schema.properties {\n' + properties + '\n} }; return schema.raw.objectValue!["properties"]!.objectValue!.count }\n'
    inner = 'Element(1)'
    for _ in range(24): inner = 'Element.array { ' + inner + ' }'
    result['nested-24'] = 'import JSONValueDSL\nfunc fixture() throws { _ = try JSONValueDSL.array { ' + inner + ' } }\n'
    result['mixed-choices-loops'] = POSITIVE
    result['inference'] = '''import JSONValueDSL
import JSONSchemaDSL
func fixture(_ include: Bool) throws {
    let fields = ["a", "b", "c"]
    _ = try JSONValueDSL.object { for (i, name) in fields.enumerated() { Field(name, UInt64(i)) }; if include { Field.object("nested") { Field("ok", true) } } }
    _ = try JSONSchemaDSL.document { Schema.properties { for name in fields { Property(name) { if include { Schema.type(.string) } else { Schema.type(.null) } } } }; Schema.prefixItems { Rule { Schema.anyOf { Rule(true); Rule(false) } } } }
}
'''
    return result


def partial_source(source):
    start = source.index('public static func buildBlock')
    opening = source.index('{', start); depth = 1; end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}'); end += 1
    replacement = '''public static func buildBlock() -> JSONContentEmpty { .init() }
    public static func buildPartialBlock<First>(first: First) -> First { first }
    public static func buildPartialBlock<Accumulated, Next>(accumulated: Accumulated, next: Next) -> JSONContentTuple<Accumulated, Next> { .init(accumulated, next) }'''
    domains = [('JSONValueFieldsContent', 'writeValueFields', 'JSONDSLMember'), ('JSONValueElementsContent', 'writeValueElements', 'JSONDSLNode'), ('JSONSchemaClausesContent', 'writeSchemaClauses', 'JSONDSLMember'), ('JSONSchemaPropertiesContent', 'writeSchemaProperties', 'JSONDSLMember'), ('JSONSchemaNodesContent', 'writeSchemaNodes', 'JSONDSLNode'), ('JSONSchemaDependenciesContent', 'writeSchemaDependencies', 'JSONDSLMember'), ('JSONSchemaPatternsContent', 'writeSchemaPatterns', 'JSONDSLMember'), ('JSONSchemaDefinitionsContent', 'writeSchemaDefinitions', 'JSONDSLMember'), ('JSONSchemaDependentSchemasContent', 'writeDependentSchemas', 'JSONDSLMember')]
    empty = '\npublic struct JSONContentEmpty: ' + ', '.join(x[0] for x in domains) + ' { public init() {}\n'
    empty += '\n'.join('public func '+method+'(to value: inout ['+kind+']) {}' for _,method,kind in domains) + '\n}\n'
    return source[:start] + replacement + source[end:] + empty


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['imports', 'compiler'], default='imports')
    parser.add_argument('--output', default='.build/ci/dual-dsl')
    args = parser.parse_args(); output = ROOT / args.output; output.mkdir(parents=True, exist_ok=True)
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    record = dict(schema_version=1, status='running', mode=args.mode, source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(), commands=[], measurements=[], source_inputs=[], started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    for directory in ['Sources/JSONDSLCore','Sources/JSONValueDSL','Sources/JSONSchemaDSL','Tests/CompileNegative/DualDSL']:
        record['source_inputs'] += [dict(path=p.relative_to(ROOT).as_posix(),sha256=sha(p)) for p in sorted((ROOT/directory).rglob('*.swift'))]
    consumer = (ROOT/'Examples/DualDSL/Sources/DualDSLConsumer/main.swift').read_text()
    assert 'JSONDSLCore' not in consumer and 'JSONWorkMeter' not in consumer
    guide_fences = 0
    for name in ['Sources/JSONValueDSL/Documentation.docc/AuthoredValues.md', 'Sources/JSONSchemaDSL/Documentation.docc/AuthoredSchemas.md']:
        blocks = re.findall(r'```swift\n(.*?)\n```', (ROOT/name).read_text(), re.S)
        assert len(blocks) == 1 and blocks[0] in consumer, name
        guide_fences += 1
    record['guide_fences'] = guide_fences
    def save(): (output/'receipt.json').write_text(json.dumps(record,indent=2)+'\n')
    def run(name, command, rejection=(), timed=False, timeout=180):
        log=output/(name+'.log'); start=time.monotonic()
        measured=['/usr/bin/time','-l']+command if timed and sys.platform=='darwin' else command
        with log.open('w') as stream:
            try: code=subprocess.run(measured,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=timeout).returncode
            except subprocess.TimeoutExpired: code=None
        elapsed=time.monotonic()-start; text=log.read_text(); bad_import=any(s in text for s in ["no such module",'cannot load module','unable to load standard library'])
        passed=code==0 if not rejection else code==1 and not bad_import and all(s in text for s in rejection)
        memory=re.search(r'(\d+)\s+maximum resident set size',text)
        row=dict(name=name,command=measured,exit_code=code,expected_rejection=list(rejection),status='passed' if passed else 'failed',seconds=elapsed,maximum_resident_set_bytes=int(memory[1]) if memory else None,log=log.relative_to(ROOT).as_posix(),log_sha256=sha(log))
        record['commands'].append(row);save()
        print(name,code,round(elapsed,3),row['status'],flush=True)
        if not passed:raise ValueError('Compiler contract failed: '+name)
        return row
    try:
        flags=['swiftc','-swift-version','6','-strict-concurrency=complete','-warnings-as-errors']
        if sys.platform=='darwin':
            sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
            flags+=['-sdk',sdk,'-target',platform.machine()+'-apple-macosx27.0']
        paths={}
        for config in ('debug','release'):
            products=pathlib.Path(subprocess.check_output(['swift','build','-c',config,'--show-bin-path'],cwd=ROOT,text=True).strip())
            include=products/'Modules' if (products/'Modules').is_dir() else products
            for module in ('JSON','JSONSchema','JSONDSLCore','JSONValueDSL','JSONSchemaDSL'):
                p=include/(module+'.swiftmodule');assert p.is_file() or p.is_dir(),p
            paths[config]=(products,include)
            source=output/(config+'-public-positive.swift');source.write_text(POSITIVE)
            run(config+'-public-positive',flags+['-I',str(include),'-typecheck',str(source)])
            source=output/(config+'-qualified-declarations.swift');source.write_text(QUALIFIED)
            run(config+'-qualified-declarations',flags+['-I',str(include),'-typecheck',str(source)])
            for filename,tokens in NEGATIVES.items():
                source=ROOT/'Tests/CompileNegative/DualDSL'/filename
                run(config+'-'+source.stem,flags+['-I',str(include),'-typecheck',str(source)],rejection=tokens)
        if args.mode=='compiler':
            if sys.platform!='darwin':raise ValueError('Native Xcode compiler comparison requires macOS')
            products,include=paths['debug']; sources=fixtures()
            record['host_observations']=dict(os=platform.platform(),load_average=os.getloadavg(),cpu_count=os.cpu_count(),policy='Concurrent host load is retained; elapsed/compiler RSS observations are not quiet-host, runtime, staging-retention or caller instruction guarantees')
            for name,text in sources.items(): (output/(name+'.swift')).write_text(text)
            identity=json.loads(subprocess.check_output(['swift','package','show-dependencies','--format','json'],cwd=ROOT,text=True))['identity']
            package=re.sub('[^a-zA-Z0-9_]','_',identity)
            alt=output/'partial';alt.mkdir(exist_ok=True)
            common=flags+['-package-name',package,'-parse-as-library','-emit-module']
            original=ROOT/'Sources/JSONDSLCore/JSONContent.swift'; changed=alt/'JSONContent.swift';changed.write_text(partial_source(original.read_text()))
            core_sources=[str(changed)]+[str(p) for p in sorted((ROOT/'Sources/JSONDSLCore').glob('*.swift')) if p.name!='JSONContent.swift']
            run('partial-core-module',common+['-module-name','JSONDSLCore','-I',str(include)]+core_sources+['-emit-module-path',str(alt/'JSONDSLCore.swiftmodule')])
            for module in ['JSONValueDSL','JSONSchemaDSL']:
                run('partial-'+module+'-module',common+['-module-name',module,'-I',str(alt),'-I',str(include)]+[str(p) for p in sorted((ROOT/'Sources'/module).glob('*.swift'))]+['-emit-module-path',str(alt/(module+'.swiftmodule'))])
            for strategy,includes in [('variadic',['-I',str(include)]),('partial',['-I',str(alt),'-I',str(include)])]:
                for name in sources:
                    row=run(strategy+'-'+name,flags+includes+['-typecheck',str(output/(name+'.swift'))],timed=True)
                    record['measurements'].append(dict(strategy=strategy,fixture=name,source_sha256=sha(output/(name+'.swift')),seconds=row['seconds'],maximum_resident_set_bytes=row['maximum_resident_set_bytes']))
            record['comparison_scope']='Both strategies compile real DSL sources against real JSON/JSONSchema; alternative modules are local experiment outputs, not shipped code or semantic shims.'
        assert len([c for c in record['commands'] if c['expected_rejection']])==12
        assert all(sha(ROOT/r['path'])==r['sha256'] for r in record['source_inputs'])
        record['status']='passed'; record['negative_fixtures']=6;record['configurations']=2
    except (OSError,ValueError,KeyError,AssertionError,subprocess.SubprocessError) as error:
        record['status']='failed';record['error']=str(error)
    record['finished_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save()
    if record['status']=='passed':print('DUAL_DSL_COMPILER passed negatives=12 configurations=2 mode='+args.mode)
    return 0 if record['status']=='passed' else 1

if __name__=='__main__':raise SystemExit(main())
