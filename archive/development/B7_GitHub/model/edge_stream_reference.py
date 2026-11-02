"""Full-image Sobel oracle: SciPy signed gradients, independent of RTL scheduling."""
import numpy as np
from scipy.ndimage import sobel
from raw_gray_reference import fixtures,gray_reference

def edge_reference(rgb,threshold=128):
    gray=gray_reference(rgb).astype(np.int32)
    magnitude=np.abs(sobel(gray,axis=1,mode='constant'))+np.abs(sobel(gray,axis=0,mode='constant'))
    result=(magnitude>=threshold).astype(np.uint8)*255
    result[[0,-1],:]=0;result[:,[0,-1]]=0
    return result
