import matplotlib.pyplot as plt
def print_hi(name):
    # Use a breakpoint in the code line below to debug your script.
    print(f'Hi, {name}')  # Press Ctrl+F8 to toggle the breakpoint.

def print(Nm):
    # Use a breakpoint in the code line below to debug your script.
   #plt.figure(figsize=(9, 3))
  # plt.subplot(131)
  #matplotlib.pyplot.bar(x, height, width=0.8, bottom=None, *, align='center', data=None, **kwargs)
   plt.bar(['neuron1', 'neuron2', 'neuron3', 'neuron4'], Nm)
   plt.ylabel('some numbers')
   plt.show()
   return 1



# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    print_hi('PyCharm')

