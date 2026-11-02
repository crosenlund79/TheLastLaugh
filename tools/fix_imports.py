"""Texture import policy: VRAM-compressed (BC7 high quality), mipmaps on, normal maps flagged."""
import glob, re, os
here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "showcase", "textures")
for f in glob.glob(os.path.join(here, "*.png.import")):
    s = open(f).read()
    normal = "_normal" in f
    s = re.sub(r"compress/mode=\d", "compress/mode=2", s)
    s = re.sub(r"compress/high_quality=\w+", "compress/high_quality=true", s)
    s = re.sub(r"compress/normal_map=\d", "compress/normal_map=%d" % (1 if normal else 2), s)
    s = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=true", s)
    s = re.sub(r"detect_3d/compress_to=\d", "detect_3d/compress_to=0", s)
    open(f, "w").write(s)
print("ok")
