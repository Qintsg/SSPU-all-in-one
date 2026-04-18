"""
SSPU All-in-One Logo 最终版
透明底 + 浅蓝粗圆环 + Fluent 风格
"""

from PIL import Image, ImageDraw, ImageFont
import os, math

SIZE = 512
CX, CY = SIZE // 2, SIZE // 2

RING_BLUE = (141, 200, 240)   # #8DC8F0
FLUENT_BLUE = (0, 120, 212)   # #0078D4
TEXT_DARK = (26, 26, 26)       # #1A1A1A
TEXT_GREEN = (109, 191, 139)   # #6DBF8B


def draw_ring(img, cx, cy, r, width, color, opacity=255):
    overlay = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    d.ellipse((cx - r, cy - r, cx + r, cy + r),
              outline=(*color, opacity), width=width)
    return Image.alpha_composite(img, overlay)


def main():
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))

    # 外圆粗环
    img = draw_ring(img, CX, CY, 240, 18, RING_BLUE, 255)

    # 内装饰环
    img = draw_ring(img, CX, CY, 222, 1, RING_BLUE, 64)

    # 分隔线
    sep = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(sep)
    d.line([(115, 168), (397, 168)], fill=(*RING_BLUE, 77), width=1)
    d.line([(115, 355), (397, 355)], fill=(*RING_BLUE, 77), width=1)
    img = Image.alpha_composite(img, sep)

    # 字体
    font_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            '..', 'assets', 'fonts')

    def load(name, size, fb='segoeui.ttf'):
        try:
            return ImageFont.truetype(os.path.join(font_dir, name), size)
        except (IOError, OSError):
            try:
                return ImageFont.truetype(fb, size)
            except (IOError, OSError):
                return ImageFont.load_default()

    font_sspu = load('MiSans-Bold.ttf', 38, 'segoeuib.ttf')
    font_aio = ImageFont.truetype('georgiaz.ttf', 62)  # Georgia Bold Italic
    font_q = load('MiSans-Regular.ttf', 22, 'segoeui.ttf')

    draw = ImageDraw.Draw(img)

    # SSPU — 半透明蓝
    sspu_overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sspu_overlay)
    bbox = sd.textbbox((0, 0), "SSPU", font=font_sspu)
    tw = bbox[2] - bbox[0]
    sd.text((CX - tw // 2, 100), "SSPU", fill=(*FLUENT_BLUE, 140), font=font_sspu)
    img = Image.alpha_composite(img, sspu_overlay)

    # All-in-One — 深色
    draw = ImageDraw.Draw(img)
    bbox = draw.textbbox((0, 0), "All-in-One", font=font_aio)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((CX - tw // 2, CX - th // 2 - 5), "All-in-One",
              fill=TEXT_DARK, font=font_aio)

    # Qintsg — 浅绿
    bbox = draw.textbbox((0, 0), "Qintsg", font=font_q)
    tw = bbox[2] - bbox[0]
    draw.text((CX - tw // 2, 370), "Qintsg", fill=TEXT_GREEN, font=font_q)

    # 装饰点
    deco = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    dd = ImageDraw.Draw(deco)
    dd.ellipse((78, CY - 2, 84, CY + 2), fill=(*RING_BLUE, 51))
    dd.ellipse((428, CY - 2, 434, CY + 2), fill=(*RING_BLUE, 51))
    img = Image.alpha_composite(img, deco)

    # 保存
    out = os.path.dirname(os.path.abspath(__file__))
    img.save(os.path.join(out, 'logo-preview.png'), 'PNG')

    # 同时保存到 assets
    assets_dir = os.path.join(out, '..', 'assets', 'images')
    os.makedirs(assets_dir, exist_ok=True)
    img.save(os.path.join(assets_dir, 'logo.png'), 'PNG')
    print('Logo saved: docs/logo-preview.png + assets/images/logo.png')

    # 生成多尺寸用于 ICO
    ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    ico_frames = []
    for s in ico_sizes:
        frame = img.resize(s, Image.Resampling.LANCZOS)
        ico_frames.append(frame)
    ico_path = os.path.join(out, '..', 'windows', 'runner', 'resources', 'app_icon.ico')
    ico_frames[0].save(ico_path, format='ICO', sizes=ico_sizes, append_images=ico_frames[1:])
    print(f'ICO saved: windows/runner/resources/app_icon.ico')


if __name__ == '__main__':
    main()
