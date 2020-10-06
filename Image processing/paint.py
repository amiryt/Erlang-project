from PIL import Image, ImageDraw, ImageEnhance, ImageOps
import PIL
from tkinter import *

image_number = 1
width = 200
height = 200
center = height // 2
white = (255, 255, 255)
green = (0, 128, 0)


def save():
    global image_number
    filename = "image" + str(image_number) + ".png"
    image1.thumbnail(size=(16, 16))
    enhancer = ImageEnhance.Contrast(image1)
    enhanced_im = enhancer.enhance(200.0)
    inverted_image = PIL.ImageOps.invert(enhanced_im)
    inverted_image = inverted_image.convert("L")  # Convert using adaptive palette of color depth 8 "L"
    # inverted_image = inverted_image.convert("P", colors=8)  # Convert using adaptive palette of color depth 8 "L"
    inverted_image.save(filename, optimize=True, quality=90)
    image_number += 1
    # print(image1.size)


def paint(event):
    x1, y1 = (event.x - 1), (event.y - 1)
    x2, y2 = (event.x + 1), (event.y + 1)
    cv.create_oval(x1, y1, x2, y2, fill="black", width=10)
    draw.line([x1, y1, x2, y2], fill="black", width=5)


def del_rect():
    global image1, draw
    cv.delete('all')
    image1 = PIL.Image.new("RGB", (width, height), white)
    draw = ImageDraw.Draw(image1)


root = Tk()

# Tkinter create a canvas to draw on
cv = Canvas(root, width=width, height=height, bg='white')
cv.pack()

# PIL create an empty image and draw object to draw on
# memory only, not visible
image1 = PIL.Image.new("RGB", (width, height), white)
draw = ImageDraw.Draw(image1)

# do the Tkinter canvas drawings (visible)
cv.pack(expand=YES, fill=BOTH)
cv.bind("<B1-Motion>", paint)

# do the PIL image/draw (in memory) drawings
button = Button(text="save", command=save)
button2 = Button(text="clear", command=del_rect)
button.pack()
button2.pack()
root.mainloop()
