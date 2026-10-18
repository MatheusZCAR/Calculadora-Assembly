"""Emulador DOS minimo (Unicorn) usado pelos testes automaticos da calculadora."""
"""Minimal DOS/BIOS emulator on top of Unicorn (16-bit real mode) for testing MZ .EXE files.

Supports: INT 21h (01,02,06,07,08,09,0B,4C), INT 10h (00,02,03,06,09,0E,0C,0F...),
INT 16h (00,01), INT 33h (mouse 00,01,02,03,04,07,08). Video memory A000 rendered to PNG.
"""
import struct
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR, UcError, UC_HOOK_CODE, UC_HOOK_INSN
from unicorn.x86_const import *

LOAD_SEG = 0x1000  # PSP segment
FORBIDDEN = {0xF6: (4, 5, 6, 7), 0xF7: (4, 5, 6, 7)}  # MUL/IMUL/DIV/IDIV via group-3 opcodes


class Stop(Exception):
    pass


class DOS:
    def __init__(self, exe_path, events, max_insns=200_000_000, trap_muldiv=True):
        self.mu = Uc(UC_ARCH_X86, UC_MODE_16)
        self.mu.mem_map(0, 0x110000)
        self.out = []          # text output stream
        self.events = list(events)  # ('key', ch) or ('click', x, y) or ('scan', ascii, scan)
        self.exit_code = None
        self.mode = 3
        self.mouse_x = 160
        self.mouse_y = 100
        self.mouse_btn = 0
        self.mouse_hold = 0
        self.muldiv_hits = []
        self.trap_muldiv = trap_muldiv
        self.max_insns = max_insns
        self.waiting_input = False
        self.idle_polls = 0
        self.load(exe_path)
        # interrupt vectors -> point to IRET stubs so INT is caught by hook
        self.mu.hook_add(UC_HOOK_INTR, self.on_int)
        self.pal = default_vga_palette()
        self.pal_idx = 0
        self.ticks = 0
        self.mu.hook_add(UC_HOOK_INSN, self.on_out, None, 1, 0, UC_X86_INS_OUT)
        if trap_muldiv:
            self.mu.hook_add(UC_HOOK_CODE, self.on_code, begin=self.code_lo, end=self.code_hi)

    def load(self, path):
        data = open(path, 'rb').read()
        if data[:2] not in (b'MZ', b'ZM'):
            # .COM
            self.mu.mem_write(LOAD_SEG * 16 + 0x100, data)
            for r in (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS):
                self.mu.reg_write(r, LOAD_SEG)
            self.mu.reg_write(UC_X86_REG_IP, 0x100)
            self.mu.reg_write(UC_X86_REG_SP, 0xFFFE)
            self.code_lo = LOAD_SEG * 16
            self.code_hi = LOAD_SEG * 16 + 0x10000
            return
        (sig, last, pages, nrel, hdrpar, minalloc, maxalloc, ss, sp, csum, ip, cs, relofs) = struct.unpack('<HHHHHHHHHHHHH', data[:26])
        size = pages * 512 - (512 - last if last else 0)
        image = data[hdrpar * 16:size]
        start_seg = LOAD_SEG + 0x10
        self.mu.mem_write(start_seg * 16, image)
        for i in range(nrel):
            off, seg = struct.unpack('<HH', data[relofs + 4 * i: relofs + 4 * i + 4])
            addr = (start_seg + seg) * 16 + off
            v = struct.unpack('<H', self.mu.mem_read(addr, 2))[0]
            self.mu.mem_write(addr, struct.pack('<H', (v + start_seg) & 0xFFFF))
        # PSP: INT 20h at 0
        self.mu.mem_write(LOAD_SEG * 16, b'\xCD\x20')
        self.mu.reg_write(UC_X86_REG_CS, start_seg + cs)
        self.mu.reg_write(UC_X86_REG_IP, ip)
        self.mu.reg_write(UC_X86_REG_SS, start_seg + ss)
        self.mu.reg_write(UC_X86_REG_SP, sp)
        self.mu.reg_write(UC_X86_REG_DS, LOAD_SEG)
        self.mu.reg_write(UC_X86_REG_ES, LOAD_SEG)
        self.code_lo = start_seg * 16
        self.code_hi = start_seg * 16 + len(image)

    def on_out(self, mu, port, size, value, _):
        if port == 0x3C8:
            self.pal_idx = (value & 0xFF) * 3
        elif port == 0x3C9:
            if self.pal_idx < 768:
                self.pal[self.pal_idx] = int((value & 63) * 255 / 63)
                self.pal_idx += 1

    # ---------------------------------------------------------------
    def on_code(self, mu, addr, size, _):
        op = mu.mem_read(addr, 2)
        b0 = op[0]
        if b0 in (0xF6, 0xF7) and ((op[1] >> 3) & 7) in (4, 5, 6, 7):
            self.muldiv_hits.append(addr)

    def r(self, reg):
        return self.mu.reg_read(reg)

    def w(self, reg, v):
        self.mu.reg_write(reg, v & 0xFFFF)

    def set_zf(self, on):
        # we return via IRET-less path: unicorn's INTR hook resumes after INT; flags are live
        fl = self.r(UC_X86_REG_EFLAGS)
        fl = (fl | 0x40) if on else (fl & ~0x40)
        self.mu.reg_write(UC_X86_REG_EFLAGS, fl)

    def next_key(self):
        """Return (ascii, scan) or raise Stop if no more input."""
        while self.events and self.events[0][0] == 'click':
            # keyboard read while a click is pending: process click by letting mouse polls see it
            return None
        if not self.events:
            raise Stop('input exhausted')
        ev = self.events.pop(0)
        if ev[0] == 'key':
            ch = ev[1]
            scan = {'\r': 0x1C, '\x08': 0x0E, '\x1b': 0x01}.get(ch, 0)
            return ord(ch), scan
        if ev[0] == 'scan':
            return ev[1], ev[2]
        raise Stop('bad event')

    def emit(self, ch):
        self.out.append(ch)

    def text(self):
        return ''.join(self.out)

    def on_int(self, mu, intno, _):
        ax = self.r(UC_X86_REG_AX)
        ah, al = ax >> 8, ax & 0xFF
        if intno == 0x21:
            if ah in (0x01, 0x07, 0x08):
                k = self.next_key()
                if k is None:
                    raise Stop('keyboard read while click pending')
                if ah == 0x01:
                    self.emit(chr(k[0]))
                self.w(UC_X86_REG_AX, (ah << 8) | k[0])
            elif ah == 0x02:
                self.emit(chr(self.r(UC_X86_REG_DX) & 0xFF))
            elif ah == 0x06:
                dl = self.r(UC_X86_REG_DX) & 0xFF
                if dl == 0xFF:
                    k = self.next_key()
                    self.w(UC_X86_REG_AX, (ah << 8) | k[0]); self.set_zf(False)
                else:
                    self.emit(chr(dl))
            elif ah == 0x09:
                ds = self.r(UC_X86_REG_DS); dx = self.r(UC_X86_REG_DX)
                a = ds * 16 + dx
                s = []
                for i in range(4096):
                    c = mu.mem_read(a + i, 1)[0]
                    if c == ord('$'):
                        break
                    s.append(chr(c))
                self.out.extend(s)
            elif ah == 0x0B:
                self.w(UC_X86_REG_AX, (ah << 8) | (0xFF if self.events else 0))
            elif ah == 0x4C or intno == 0x20:
                self.exit_code = al
                raise Stop('exit')
            else:
                raise Stop(f'unhandled int21 ah={ah:02x}')
        elif intno == 0x20:
            self.exit_code = 0
            raise Stop('exit')
        elif intno == 0x10:
            if ah == 0x00:
                self.mode = al & 0x7F
                if self.mode == 3:
                    self.emit('\f')  # clear-screen marker
                if self.mode == 0x13 and not (al & 0x80):
                    mu.mem_write(0xA0000, b'\x00' * 64000)
            elif ah == 0x0F:
                self.w(UC_X86_REG_AX, (80 << 8) | self.mode)
            elif ah == 0x0E:
                if self.mode == 3:
                    self.emit(chr(al))
            elif ah in (0x01, 0x02, 0x03, 0x05, 0x06, 0x07, 0x09, 0x0A, 0x0B, 0x10, 0x11, 0x12, 0x13):
                if ah == 0x03:
                    self.w(UC_X86_REG_DX, 0); self.w(UC_X86_REG_CX, 0)
                if ah == 0x06 and self.mode == 3:
                    self.emit('\f')
            elif ah == 0x0C:
                x = self.r(UC_X86_REG_CX); y = self.r(UC_X86_REG_DX)
                if x < 320 and y < 200:
                    mu.mem_write(0xA0000 + y * 320 + x, bytes([al]))
            else:
                raise Stop(f'unhandled int10 ah={ah:02x}')
        elif intno == 0x16:
            if ah in (0x00, 0x10):
                k = self.next_key()
                if k is None:
                    raise Stop('kbd wait with click pending')
                self.w(UC_X86_REG_AX, (k[1] << 8) | k[0])
            elif ah in (0x01, 0x11):
                if self.events and self.events[0][0] in ('key', 'scan'):
                    ev = self.events[0]
                    if ev[0] == 'key':
                        a = ord(ev[1]); s = {'\r': 0x1C, '\x08': 0x0E, '\x1b': 0x01}.get(ev[1], 0)
                    else:
                        a, s = ev[1], ev[2]
                    self.w(UC_X86_REG_AX, (s << 8) | a); self.set_zf(False)
                else:
                    self.set_zf(True)
                    self._idle()
            else:
                raise Stop(f'unhandled int16 ah={ah:02x}')
        elif intno == 0x33:
            if ax == 0x0000:
                self.w(UC_X86_REG_AX, 0xFFFF); self.w(UC_X86_REG_BX, 2)
            elif ax in (0x0001, 0x0002, 0x0007, 0x0008, 0x0004, 0x000F, 0x000A):
                pass
            elif ax == 0x0003:
                if self.mouse_hold > 0:
                    self.mouse_hold -= 1
                    if self.mouse_hold == 0:
                        self.mouse_btn = 0
                elif self.events and self.events[0][0] == 'click':
                    ev = self.events.pop(0)
                    self.mouse_x, self.mouse_y = ev[1], ev[2]
                    self.mouse_btn = 1
                    self.mouse_hold = 3
                else:
                    self._idle()
                # mode 13h: driver reports x in 0..639
                self.w(UC_X86_REG_BX, self.mouse_btn)
                self.w(UC_X86_REG_CX, self.mouse_x * 2 if self.mode == 0x13 else self.mouse_x)
                self.w(UC_X86_REG_DX, self.mouse_y)
            else:
                raise Stop(f'unhandled int33 ax={ax:04x}')
        elif intno == 0x1A:
            self.ticks += 1
            self.w(UC_X86_REG_CX, 0); self.w(UC_X86_REG_DX, self.ticks // 50)
        else:
            raise Stop(f'unhandled int {intno:02x} ax={ax:04x}')

    def _idle(self):
        if not self.events and self.mouse_hold == 0:
            self.idle_polls += 1
            if self.idle_polls > 2000:
                raise Stop('input exhausted (idle)')

    def run(self):
        cs = self.r(UC_X86_REG_CS); ip = self.r(UC_X86_REG_IP)
        start = cs * 16 + ip
        while True:
            try:
                cs = self.r(UC_X86_REG_CS); ip = self.r(UC_X86_REG_IP)
                self.mu.emu_start(cs * 16 + ip, 0x110000, count=self.max_insns)
                return 'insn limit'
            except Stop as e:
                return str(e)
            except UcError as e:
                cs = self.r(UC_X86_REG_CS); ip = self.r(UC_X86_REG_IP)
                return f'cpu error {e} at {cs:04x}:{ip:04x}'

    def framebuffer_png(self, path, palette=None, scale=3):
        from PIL import Image
        fb = bytes(self.mu.mem_read(0xA0000, 64000))
        img = Image.frombytes('P', (320, 200), fb)
        img.putpalette(palette or self.pal)
        img = img.convert('RGB').resize((320 * scale, 200 * scale), Image.NEAREST)
        img.save(path)


def default_vga_palette():
    # standard 16 EGA colors + 216 web cube + greys approximating VGA default
    base16 = [(0,0,0),(0,0,170),(0,170,0),(0,170,170),(170,0,0),(170,0,170),(170,85,0),(170,170,170),
              (85,85,85),(85,85,255),(85,255,85),(85,255,255),(255,85,85),(255,85,255),(255,255,85),(255,255,255)]
    pal = []
    for c in base16:
        pal += c
    for i in range(16):
        v = int(i * 255 / 15)
        pal += (v, v, v)
    while len(pal) < 768:
        pal += (0, 0, 0)
    return pal


def keys(s):
    return [('key', c) for c in s]
