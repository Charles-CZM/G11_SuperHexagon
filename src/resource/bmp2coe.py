# Author: Charles Chen
# This script converts an input image to a memory initialization file (coe format) in bit-map format. 
# Input image must be black and white with each pixel having a value of either 255 (white) or 0 (black).
# The output coe file can be used to initialize RAM Blocks in a Vivado block design.

import os
from scipy import misc

image_path = './start_screen.bmp'
image = misc.imread(image_path, flatten= 0)
output_path = './start_screen.coe'
f = open(output_path, "w")

for row in image:
	for i in range(len(row)/32):
		word = 0
		for j in range(32):
			pixel = row[32*i+j]
			if pixel == 255:
				word = word << 1 | 1
			else:
				word = word << 1
		f.write("%08x\n" % word)

f.close()
