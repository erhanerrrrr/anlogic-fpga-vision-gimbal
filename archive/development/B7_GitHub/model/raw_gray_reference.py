"""Full-image integer grayscale oracle, independent of RTL registers/products."""
import numpy as np
from rgb_mask_reference import fixtures as pair_fixtures

def gray_reference(rgb):
    values=rgb.astype(np.uint32)
    return ((values @ np.array([77,150,29],dtype=np.uint32)+128)//256).astype(np.uint8)

def fixtures(w,h):
    cases=pair_fixtures(w,h)
    # Gray ramp: every level is exact identity, including black and white.
    rgb,tag=cases[4]
    ramp=np.arange(w,dtype=np.uint32)*255//(w-1)
    rgb[:]=ramp[None,:,None]
    return cases
