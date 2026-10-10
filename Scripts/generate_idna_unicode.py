#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Original RFC 5892/5893 and NFC tables from fixed Unicode 13.0.0 inputs.

No Python/system Unicode database is consulted. Regeneration validates the
pinned Unicode normalization corpus before emitting immutable runtime tables.
"""
import argparse, functools, hashlib, json
from pathlib import Path
from generate_regex_unicode import rows, ranges
FILES=['ReadMe.txt','UnicodeData.txt','CaseFolding.txt','DerivedNormalizationProps.txt','DerivedCoreProperties.txt',
       'PropList.txt','Blocks.txt','HangulSyllableType.txt','Scripts.txt','extracted/DerivedJoiningType.txt','NormalizationTest.txt','IdnaMappingTable.txt']

def generate(root):
    assert 'Version 13.0.0' in (root/'ReadMe.txt').read_text()
    category=['Cn']*0x110000; ccc=[0]*0x110000; bidi=[0]*0x110000; script=[0]*0x110000; joining=[0]*0x110000
    decomp={}; canonical={}; fold={}; exclusions=set()
    bvalues={'R':1,'AL':2,'L':3,'EN':4,'AN':5,'ES':6,'CS':7,'ET':8,'ON':9,'BN':10,'NSM':11}
    first=None
    for row in rows(root/'UnicodeData.txt'):
        cp=int(row[0],16)
        if row[1].endswith(', First>'): first=cp; continue
        points=range(first,cp+1) if row[1].endswith(', Last>') else [cp]
        for point in points: category[point]=row[2]; ccc[point]=int(row[3]); bidi[point]=bvalues.get(row[4],0)
        first=None
        if row[5]:
            pieces=row[5].split(); compatible=pieces[0].startswith('<')
            value=tuple(int(piece,16) for piece in (pieces[1:] if compatible else pieces))
            decomp[cp]=value
            if not compatible: canonical[cp]=value
    for row in rows(root/'CaseFolding.txt'):
        if row[1] in ('C','F'): fold[int(row[0],16)]=tuple(int(x,16) for x in row[2].split())
    for row in rows(root/'DerivedNormalizationProps.txt'):
        if row[1]=='Full_Composition_Exclusion':
            bounds=row[0].split('..'); exclusions.update(range(int(bounds[0],16),int(bounds[-1],16)+1))
    composition={(v[0],v[1]):cp for cp,v in canonical.items() if len(v)==2 and cp not in exclusions}
    @functools.lru_cache(None)
    def decomposition(cp,compat):
        if 0xAC00 <= cp <= 0xD7A3:
            n=cp-0xAC00; value=(0x1100+n//588,0x1161+(n%588)//28)
            return value+(0x11A7+n%28,) if n%28 else value
        mapping=(decomp if compat else canonical).get(cp)
        return tuple(p for x in mapping for p in decomposition(x,compat)) if mapping else (cp,)
    def compose(a,b):
        if 0x1100<=a<=0x1112 and 0x1161<=b<=0x1175: return 0xAC00+(a-0x1100)*588+(b-0x1161)*28
        if 0xAC00<=a<=0xD7A3 and (a-0xAC00)%28==0 and 0x11A8<=b<=0x11C2: return a+b-0x11A7
        return composition.get((a,b))
    def normalize(value,compat=False):
        ordered=[]
        for cp in value:
            for point in decomposition(cp,compat):
                pos=len(ordered); ordered.append(point)
                while ccc[point] and pos and ccc[ordered[pos-1]]>ccc[point]: ordered[pos]=ordered[pos-1]; pos-=1
                ordered[pos]=point
        result=[]; starter=None; last=0
        for cp in ordered:
            composed=compose(result[starter],cp) if starter is not None and (last<ccc[cp] or last==0) else None
            if composed is not None: result[starter]=composed
            else:
                if ccc[cp]==0: starter=len(result)
                result.append(cp); last=ccc[cp]
        return tuple(result)
    normalization_cases=0
    for row in rows(root/'NormalizationTest.txt'):
        if row[0].startswith('@'): continue
        a,b,c,d,e=[tuple(int(x,16) for x in col.split()) for col in row[:5]]
        assert normalize(a)==b and normalize(b)==b and normalize(c)==b and normalize(d)==d and normalize(e)==d
        assert all(normalize(x,True)==d for x in (a,b,c,d,e))
        normalization_cases+=1
    def pointset(paths,names):
        result=set()
        for path in paths:
            for key,values in ranges(root/path).items():
                if key in names:
                    for a,b in values: result.update(range(a,b+1))
        return result
    ignored=pointset(['DerivedCoreProperties.txt','PropList.txt'],{'Default_Ignorable_Code_Point','White_Space','Noncharacter_Code_Point'})
    blocks=pointset(['Blocks.txt'],{'Combining Diacritical Marks for Symbols','Musical Symbols','Ancient Greek Musical Notation'})
    oldjamo=pointset(['HangulSyllableType.txt'],{'L','V','T'})
    for name,value in {'Greek':1,'Hebrew':2,'Hiragana':3,'Katakana':4,'Han':5}.items():
        for a,b in ranges(root/'Scripts.txt').get(name,[]): script[a:b+1]=[value]*(b-a+1)
    for name,value in {'D':1,'L':2,'R':3,'T':4}.items():
        for a,b in ranges(root/'extracted/DerivedJoiningType.txt').get(name,[]): joining[a:b+1]=[value]*(b-a+1)
    exceptions={cp:1 for cp in [0xDF,0x3C2,0x6FD,0x6FE,0xF0B,0x3007]}
    exceptions.update({cp:3 for cp in [0xB7,0x375,0x5F3,0x5F4,0x30FB]+list(range(0x660,0x66A))+list(range(0x6F0,0x6FA))})
    exceptions.update({cp:0 for cp in [0x640,0x7FA,0x302E,0x302F,0x3031,0x3032,0x3033,0x3034,0x3035,0x303B]})
    packed=[]
    for cp in range(0x110000):
        gc=category[cp]
        if cp in exceptions: valid=exceptions[cp]
        elif gc=='Cn': valid=0
        elif cp==45 or 48<=cp<=57 or 97<=cp<=122: valid=1
        elif cp in (0x200C,0x200D): valid=2
        elif cp in ignored or cp in blocks or cp in oldjamo or gc not in ('Ll','Lu','Lo','Nd','Lm','Mn','Mc'): valid=0
        else:
            kc=normalize((cp,),True); folded=tuple(x for p in kc for x in fold.get(p,(p,)))
            valid=int(normalize(folded,True)==(cp,))
        packed.append(valid | (4 if gc in ('Mn','Mc','Me') else 0) | (ccc[cp]<<8) | (bidi[cp]<<16) | (script[cp]<<21) | (joining[cp]<<24))
    values=[]; start=0
    for cp in range(1,len(packed)+1):
        if cp==len(packed) or packed[cp]!=packed[start]:
            if packed[start]: values.extend([start,cp-1,packed[start]])
            start=cp
    dindex=[]; dvalues=[]
    for cp in sorted(canonical):
        value=decomposition(cp,False); dindex.extend([cp,len(dvalues),len(value)]); dvalues.extend(value)
    cvalues=sorted((a<<42)|(b<<21)|cp for (a,b),cp in composition.items())
    def swift(name,items,type='UInt32'):
        lines=[f'    static let {name}: [{type}] = [']
        for i in range(0,len(items),12): lines.append('        '+','.join(hex(x) for x in items[i:i+12])+',')
        return '\n'.join(lines+['    ]'])
    code='// SPDX-License-Identifier: Apache-2.0\n// Unicode data © 2020 Unicode, Inc. License: Licenses/Unicode-3.0.txt.\n// Generated by Scripts/generate_idna_unicode.py; do not edit. Unicode 13.0.0.\npackage enum JSONIDNAData {\n'
    mappings=[]; mapped=[]
    assert 'Version: 13.0.0' in (root/'IdnaMappingTable.txt').read_text()
    for row in rows(root/'IdnaMappingTable.txt'):
        bounds=row[0].split('..'); status={'valid':1,'deviation':1,'mapped':2,'ignored':3}.get(row[1],0)
        value=[int(x,16) for x in row[2].split()] if status==2 else []
        mappings.extend([int(bounds[0],16),int(bounds[-1],16),status,len(mapped),len(value)]); mapped.extend(value)
    code+='\n'.join([swift('mappingIndex',mappings),swift('mappingScalars',mapped),swift('properties',values),swift('decompositionIndex',dindex),swift('decompositionScalars',dvalues),swift('composition',cvalues,'UInt64')])+'\n}\n'
    return code,{'unicode_version':'13.0.0','algorithm':['RFC5892','RFC5893','RFC3492','Unicode13-NFC'],
        'normalization_cases':normalization_cases,'normalization_comparisons':normalization_cases*10,
        'property_ranges':len(values)//3,'canonical_decompositions':len(dindex)//3,'composition_pairs':len(cvalues),'uts46_mapping_ranges':len(mappings)//5,'idn_processing':'UTS46 nontransitional STD3 followed by RFC5892/5893'}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('ucd',type=Path);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    root=Path(__file__).resolve().parents[1];code,metadata=generate(args.ucd)
    output=root/'Sources/JSONSchema/Formats/JSONIDNAData.swift'
    metadata['inputs']=[{'path':name,'sha256':hashlib.sha256((args.ucd/name).read_bytes()).hexdigest()} for name in FILES]
    metadata['generator_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    metadata['output_sha256']=hashlib.sha256(code.encode()).hexdigest()
    metadata['license_sha256']=hashlib.sha256((root/'Licenses/Unicode-3.0.txt').read_bytes()).hexdigest()
    receipt=root/'Documentation/Qualification/IDNAProvenance.json';data=json.dumps(metadata,indent=2)+'\n'
    if args.check: assert output.read_text()==code and receipt.read_text()==data;print('IDNA regeneration matches')
    else: output.write_text(code);receipt.write_text(data);print(json.dumps({k:v for k,v in metadata.items() if k!='inputs'}))
if __name__=='__main__': main()
