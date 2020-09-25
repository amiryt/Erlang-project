from numpy import *
import imageio
import math
from matplotlib.pyplot import *


def rf(inp):
    sca1 = 0.625
    sca2 = 0.125
    sca3 = -0.125
    sca4 = -0.5

    # Receptive field kernel
    w = [[sca4, sca3, sca2, sca3, sca4],
         [sca3, sca2, sca1, sca2, sca3],
         [sca2, sca1, 1, sca1, sca2],
         [sca3, sca2, sca1, sca2, sca3],
         [sca4, sca3, sca2, sca3, sca4]]

    pot = np.zeros([inp.shape[0], inp.shape[1]])
    ran = [-2, -1, 0, 1, 2]
    ox = 2
    oy = 2

    # Convolution
    for i in range(inp.shape[0]):
        for j in range(inp.shape[1]):
            summ = 0
            for m in ran:
                for n in ran:
                    if (i + m) >= 0 and (i + m) <= inp.shape[0] - 1 and (j + n) >= 0 and (j + n) <= inp.shape[0] - 1:
                        summ = summ + w[ox + m][oy + n] * inp[i + m][j + n] / 255
            pot[i][j] = summ
    return pot


def reconst_rf(weights, num):
    pixel_x = 16
    pixel_y = 16
    weights = np.array(weights)
    weights = np.reshape(weights, (pixel_x, pixel_y))
    img = np.zeros((pixel_x, pixel_y))
    for i in range(pixel_x):
        for j in range(pixel_y):
            img[i][j] = int(interp(weights[i][j], [-2, 3.625], [0, 255]))

    imageio.imwrite('neuron' + str(num) + '.png', img)
    return img


def encode(T, dt, pot):
    # initializing spike train
    train = []

    for l in range(pot.shape[0]):
        for m in range(pot.shape[1]):

            time = np.arange(0, T + dt, dt)
            # t_test = T
            # I think
            t_test = len(time)
            temp = np.zeros([(t_test + 1), ])
            # calculating firing rate proportional to the membrane potential
            freq = interp(pot[l][m], [-1.069, 2.781], [1, 20])
            # print(pot[l][m], freq)
            # print freq

            assert freq > 0
            # freq1_test = math.ceil(600 / freq)
            # I think
            freq1_test = math.ceil((t_test - 1) / freq)

            # generating spikes according to the firing rate
            k = freq1_test
            if (pot[l][m] > 0):
                while k < (t_test + 1):
                    temp[int(k)] = 1
                    k = k + freq1_test
            train.append(temp)
            # print sum(temp)
    return train


def encode2(T, dt, pot):
    # defining time frame of 1s with steps of 5ms
    # T = 1
    # dt = 0.005
    time = np.arange(0, T + dt, dt)

    # initializing spike train
    train = []
    for l in range(16):
        for m in range(16):

            temp = np.zeros([len(time), ])
            # calculating firing rate proportional to the membrane potential
            freq = math.ceil(0.102 * pot[l][m] + 52.02)
            freq1 = math.ceil((len(time) - 1) / freq)

            # generating spikes according to the firing rate
            k = 0
            while k < (len(time) - 1):
                temp[k] = 1
                k = k + freq1
            train.append(temp)
    return train


def getImageTraing(Num):
    image= str(Num)+".jpg"
    img = imageio.imread(image)
    pot = rf(img)
    train = encode(50, 0.125, pot)
    #f = open(train_text, 'w')
    #print(np.shape(train))
    Image=[]
    Imagei=[]
    for j in range(len(train)):
        Imagei=[] 
        for i in range(len(train[j])):
            Imagei.append(train[j][i])
        Image.append(Imagei)

    print(Image)
    return Image




if __name__== '__main__':
      getImageTraing()
    #return Image



    # with open(train_text, 'r') as f:
    #     pixels = []
    #     for line in f:
    #         sum = 0
    #         for i in line:
    #             if i == '1':
    #                 sum += 1
    #         pixels.append(sum)
    #     pixels = np.array(pixels, 'float64')
    #     pixels = pixels / np.max(pixels) * 255.0
    #     dim = int(math.sqrt(len(pixels)))
    #     img = np.array(pixels, 'uint8').reshape((dim, dim))
    #     imshow(img)
    #     show()

    # img = imageio.imread("image1.png")
    # pot = rf(img)
    # reconst_rf(pot, 12)
    # T = 1
    # dt = 0.005
    # train = encode(T, dt, pot)  # defining time frame of 1s with steps of 5ms
    # time = np.arange(0, T + dt, dt)
    # # plot(time, train[6])
    # max_a = []
    # min_a = []
    # for i in pot:
    #     max_a.append(max(i))
    #     min_a.append(min(i))
    # for i in range(16):
    #     temp = ''
    #     for j in pot[i]:
    #         temp += '%02d ' % int(j)
    #     print(temp)
    # print("max", max(max_a))
    # print("min", min(min_a))