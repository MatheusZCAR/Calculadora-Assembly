"""Testa bin/CALC.EXE: milhares de contas comparadas com Python."""
import random, re, time
import os, sys
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
RAIZ = os.path.dirname(AQUI)
from dosemu import DOS, keys
EXE=os.path.join(RAIZ,'bin','CALC.EXE')
LO,HI=-2**31,2**31-1
def ref(op,a,b):
    if op=='1': r=a+b
    elif op=='2': r=a-b
    elif op=='3': r=a*b
    else:
        q=abs(a)//abs(b); q = q if (a<0)==(b<0) else -q
        r_=a-q*b
        if not LO<=q<=HI: return 'ERR'
        return (q,r_)
    return r if LO<=r<=HI else 'ERR'
edges=[0,1,-1,2,-2,7,-7,9,10,-10,99,12345,-12345,65535,65536,-65536,32767,-32768,46340,46341,-46341,
       2**31-1,-2**31,2**30,-2**30,1000000000,-1000000000,999999999,123456789,-987654321]
random.seed(1)
cases=[]
for op in '1234':
    for a in edges:
        for b in edges:
            if op=='4' and b==0: continue
            cases.append((op,a,b))
for _ in range(1500):
    op=random.choice('1234')
    a=random.choice([random.randint(LO,HI), random.randint(-1000,1000), random.randint(-70000,70000)])
    b=random.choice([random.randint(LO,HI), random.randint(-1000,1000), random.randint(-70000,70000),random.randint(-50,50)])
    if op=='4' and b==0: b=3
    cases.append((op,a,b))
print('cases',len(cases))
fails=[]; t0=time.time(); hits=set()
B=200
for i in range(0,len(cases),B):
    chunk=cases[i:i+B]
    seq=''
    for k,(op,a,b) in enumerate(chunk):
        seq+=op+str(a)+'\r'+str(b)+'\r'+('s' if k<len(chunk)-1 else 'n')
    d=DOS(EXE, keys(seq)); st=d.run(); hits|=set(d.muldiv_hits)
    t=d.text()
    blocks=t.split('\f')[1:]
    assert len(blocks)==len(chunk),(len(blocks),st,t[-500:])
    for blk,(op,a,b) in zip(blocks,chunk):
        exp=ref(op,a,b)
        if 'Erro' in blk: got='ERR'
        elif op=='4':
            got=(int(re.search(r'Quociente: (-?\d+)',blk).group(1)),int(re.search(r'Resto: (-?\d+)',blk).group(1)))
        else:
            got=int(re.search(r'Resultado: (-?\d+)',blk).group(1))
        if got!=exp: fails.append((op,a,b,got,exp))
    if st!='exit': print('status',st)
print('falhas',len(fails),fails[:10]); print('MUL/DIV executados:',len(hits)); print('tempo %.1fs'%(time.time()-t0))
sys.exit(1 if fails or hits else 0)
