import matplotlib.pyplot as plt
import matplotlib.image as mpimg


def print_hi(name):
    # Use a breakpoint in the code line below to debug your script.
    print(f'Hi, {name}')  # Press Ctrl+F8 to toggle the breakpoint.


def close_event():
    plt.close()  # timer calls this function after 3 seconds and closes the window


def showImg(Nm):
    fig = plt.figure()
    fig.suptitle('you sent this image', fontsize=16)
    timer = fig.canvas.new_timer(interval=5000)  # creating a timer object and setting an interval of 3000 milliseconds
    timer.add_callback(close_event)
    dest = "/home/kyan/Desktop/finalWorks/Images/image" + str(Nm) + ".jpg"
    timer.start()
    img = mpimg.imread(dest)
    imgplot = plt.imshow(img)
    plt.show()
    return 1


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    showImg(3)
