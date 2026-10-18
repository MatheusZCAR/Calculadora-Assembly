"""Testa bin/CALCGUI.EXE clicando nos botoes (mouse simulado) e lendo o visor da tela VGA.

Uso:  python3 testes/testa_gui.py        (requer: pip install unicorn pillow)
"""
import os, sys, re, random
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
RAIZ = os.path.dirname(AQUI)
from dosemu import DOS

EXE = os.path.join(RAIZ, 'bin', 'CALCGUI.EXE')
LO, HI = -2**31, 2**31 - 1

# ---- "OCR": compara cada bloco da tela com a mesma fonte que o programa usa ----
fonte = {}
for m in re.finditer(r'DB ((?:0[0-9A-F]{2}h,?){8})\s*;\s*(\d+)', open(os.path.join(RAIZ, 'fonte8x8.inc')).read()):
    fonte[int(m.group(2))] = [int(x[:-1], 16) for x in m.group(1).split(',')]
ESPECIAIS = {127: '÷', 128: '±', 129: '<-'}

def bits(fb, x, y, esc, fundo):
    linhas = []
    for r in range(8):
        v = 0
        for c in range(8):
            v = (v << 1) | (fb[(y + r * esc) * 320 + x + c * esc] != fundo)
        linhas.append(v)
    return linhas

def le_linha(fb, y, esc, direita, fundo=33):
    txt, x = '', direita
    while x - 8 * esc >= 9:
        x -= 8 * esc
        g = bits(fb, x, y, esc, fundo)
        if not any(g):
            if x - 8 * esc < 9 or not any(bits(fb, x - 8 * esc, y, esc, fundo)):
                break
            txt = ' ' + txt
            continue
        achou = [c for c, b in fonte.items() if b == g]
        c = achou[0] if achou else None
        txt = (ESPECIAIS.get(c) or (chr(c) if c else '?')) + txt
    return txt

def visor(d):
    """(historico, numero grande, linha de info) lidos da memoria de video."""
    fb = bytes(d.mu.mem_read(0xA0000, 64000))
    return le_linha(fb, 21, 1, 304), le_linha(fb, 32, 2, 304), le_linha(fb, 52, 1, 304)

# ---- botoes: mesma grade do CalcGUI.asm ----
COLS = [9, 86, 163, 240]
LINS = [70, 96, 122, 148, 174]
GRADE = [['C', 'E', 'B', '/'], ['7', '8', '9', '*'], ['4', '5', '6', '-'], ['1', '2', '3', '+'], ['Q', '0', 'N', '=']]
CENTRO = {GRADE[l][c]: (COLS[c] + 35, LINS[l] + 11) for l in range(5) for c in range(4)}

def cliques(s):
    return [('click',) + CENTRO[ch] for ch in s]

def roda(eventos):
    d = DOS(EXE, eventos)
    st = d.run()
    return d, st

def conta(a, op, b):
    if op == '+': r = a + b
    elif op == '-': r = a - b
    elif op == '*': r = a * b
    else:
        if b == 0: return None
        q = abs(a) // abs(b)
        r = q if (a < 0) == (b < 0) else -q
    return r if LO <= r <= HI else None

if __name__ == '__main__':
    falhas = 0
    casos = [
        ('12+30*2=',     ('42 x 2 =', '84', '')),
        ('17/5=',        ('17 ÷ 5 =', '3', 'resto: 2')),
        ('7N/2=',        ('-7 ÷ 2 =', '-3', 'resto: -1')),
        ('5/0=',         ('5 ÷ 0 =', 'ERRO', 'nao da para dividir por zero')),
        ('5/0=8',        ('', '8', '')),
        ('99999*99999=', ('99999 x 99999 =', 'ERRO', 'estouro: passa de 32 bits')),
        ('99999999999',  ('', '999999999', '')),
        ('1234BB',       ('', '12', '')),
        ('12+34E5=',     ('12 + 5 =', '17', '')),
        ('9+-*3=',       ('9 x 3 =', '27', '')),
        ('5+=',          ('5 + 5 =', '10', '')),
        ('6*7=N',        ('', '-42', '')),
        ('100+205=',     ('100 + 205 =', '305', '')),
    ]
    for seq, esperado in casos:
        d, st = roda(cliques(seq))
        obtido = visor(d)
        ok = obtido == esperado and not d.muldiv_hits
        falhas += not ok
        print(('ok   ' if ok else 'FALHA'), f'{seq:16s}', obtido)

    # contas encadeadas aleatorias, metade pelo mouse e metade pelo teclado
    random.seed(7)
    N = 300
    for t in range(N):
        n = random.randint(2, 4)
        nums = [random.choice([random.randint(-99999, 99999), random.randint(-99, 99),
                               random.randint(LO, HI), random.randint(0, 9)]) for _ in range(n)]
        ops = [random.choice('+-*/') for _ in range(n - 1)]
        acc = nums[0]
        for i, (op, b) in enumerate(zip(ops, nums[1:])):
            acc = conta(acc, op, b)
            if acc is None:          # erro: corta a sequencia ai (depois do ERRO a GUI recomeca)
                nums, ops = nums[:i + 2], ops[:i + 1]
                break
        seq = ''.join(str(abs(x)) + ('N' if x < 0 else '') + (ops[j] if j < len(ops) else '')
                      for j, x in enumerate(nums)) + '='
        esperado = 'ERRO' if acc is None else str(acc)
        if t % 2:
            ev = cliques(seq)
        else:
            ev = [('key', {'N': 'n', '=': '\r', '*': 'x'}.get(c, c)) for c in seq]
        d, st = roda(ev)
        obtido = visor(d)[1]
        if obtido != esperado or d.muldiv_hits:
            falhas += 1
            print('FALHA', seq, 'obtido', obtido, 'esperado', esperado)
    print(f'contas aleatorias: {N}')

    d, st = roda(cliques('12Q'))
    ok = st == 'exit' and d.exit_code == 0
    falhas += not ok
    print('botao SAIR:', 'ok' if ok else 'FALHA')
    print('falhas:', falhas)
    sys.exit(1 if falhas else 0)
