#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Reproducible independent fixtures: Python integer/Fraction only, never float."""
from fractions import Fraction
import hashlib, json, pathlib, random, sys
SEED=0x140C3
rng=random.Random(SEED)
rows=[]
def decimal(value):
    n,d=value.numerator,value.denominator; negative=n<0;n=abs(n);a=b=0
    while d%2==0:d//=2;a+=1
    while d%5==0:d//=5;b+=1
    assert d==1
    places=max(a,b);coefficient=n*2**(places-a)*5**(places-b)
    text=str(coefficient).rjust(places+1,'0')
    if places:text=text[:-places]+'.'+text[-places:];text=text.rstrip('0').rstrip('.')
    return ('-' if negative and coefficient else '')+text

def add(op,a,b=None,scale=None):
    x=Fraction(a);y=Fraction(b) if b is not None else None;rounded=0
    if op=='+':z=x+y
    elif op=='-':z=x-y
    elif op=='*':z=x*y
    elif op=='/':
        z=x/y
        if scale is not None:
            n,d=abs(z.numerator)*10**scale,z.denominator;q,r=divmod(n,d)
            rounded=int(r!=0)
            if r*2>d or r*2==d and q%2:q+=1
            z=Fraction((-q if z<0 else q),10**scale)
    elif op=='%':
        q=abs(x.numerator)//abs(y.numerator);q=-q if (x<0)!=(y<0) else q;z=x-q*y
    elif op=='abs':z=abs(x)
    elif op=='negate':z=-x
    elif op=='trunc':z=Fraction(int(x))
    elif op=='floor':z=Fraction(x.numerator//x.denominator)
    elif op=='ceil':z=Fraction(-((-x.numerator)//x.denominator))
    elif op=='round':
        n,d=abs(x.numerator),x.denominator;q,r=divmod(n,d);q+=r*2>=d;z=Fraction(-q if x<0 else q)
    row={'id':len(rows),'op':op,'lhs':a,'expected':decimal(z),'rounded':rounded}
    if b is not None:row['rhs']=b
    if scale is not None:row['scale']=scale
    rows.append(row)
for _ in range(120):
    a=str(rng.randint(-10**25,10**25))+'e'+str(rng.randint(-6,6));b=str(rng.randint(-10**25,10**25))+'e'+str(rng.randint(-6,6))
    for op in ('+','-','*'):add(op,a,b)
for _ in range(80):
    a=str(rng.randint(-10**18,10**18));b=str((2**rng.randint(0,24)*5**rng.randint(0,24))*rng.choice((-1,1)))
    add('/',a,b)
for _ in range(80):
    a=str(rng.randint(-10**12,10**12))+'e'+str(rng.randint(-3,3));b=str(rng.choice((3,6,7,9,11,13,17))*rng.choice((-1,1)))
    add('/',a,b,scale=rng.randint(0,8))
for _ in range(64):add('%',str(rng.randint(-10**30,10**30)),str(rng.randint(1,10**15)*rng.choice((-1,1))))
for value in ['-0','1.5','-1.5','0.5','-0.5','2.5','-2.5','999.999','-999.999','1e-100','-1e-100','1e100','-1e100','0.1','-0.1','5','-5','2.49','-2.49','2.51','-2.51','9007199254740993.5','-9007199254740993.5','0']:
    for op in ('abs','negate','floor','ceil','trunc','round'):add(op,value)
for a,b,scale in [('1','8',2),('3','8',2),('-1','8',2),('5','2',0),('7','2',0),('-5','2',0),('1','3',4),('1','40',2),('1','100',2),('1','100',0)]:add('/',a,b,scale)
result={'schema_version':1,'oracle':'Python fractions.Fraction and arbitrary-width integers; no float/Decimal','seed':SEED,'count':len(rows),'cases':rows}
output=pathlib.Path(sys.argv[1]);output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'count':len(rows),'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'python':sys.version}))
