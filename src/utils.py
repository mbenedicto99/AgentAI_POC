import re, os, time, glob

def read_txt_files(folder="data/inbox"):
    paths = sorted(glob.glob(os.path.join(folder,"*.txt")) + glob.glob(os.path.join(folder,"*.md")))
    for p in paths:
        with open(p, 'r', encoding='utf-8') as f:
            yield os.path.basename(p), f.read()

def chunk(text, max_chars=1200):
    parts = re.split(r'\n\s*\n', text)
    chunks, buf = [], ""
    for p in parts:
        if len(buf)+len(p) < max_chars:
            buf += ("\n\n"+p) if buf else p
        else:
            if buf: chunks.append(buf); buf=""
            if len(p)<=max_chars: chunks.append(p)
            else:
                for i in range(0, len(p), max_chars):
                    chunks.append(p[i:i+max_chars])
    if buf: chunks.append(buf)
    return [c.strip() for c in chunks if c.strip()]

class Timer:
    def __enter__(self): self.t=time.perf_counter(); return self
    def __exit__(self, *args): self.dt=time.perf_counter()-self.t
