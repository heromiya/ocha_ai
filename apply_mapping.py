import os, shutil, tempfile, random, glob, subprocess, errno, datetime, numpy as np
import tensorflow as tf, keras

from PIL import Image
from keras.models import Model
from keras.layers import Conv2D, MaxPooling2D, Input, Conv2DTranspose, Concatenate, BatchNormalization, UpSampling2D
from keras.layers import  Dropout, Activation
from keras.optimizers import Adam, SGD
from keras.layers.advanced_activations import LeakyReLU
from keras.callbacks import ModelCheckpoint, ReduceLROnPlateau, EarlyStopping
from keras import backend as K
from keras.utils import plot_model
from random import shuffle
from keras.preprocessing.image import ImageDataGenerator
from keras.utils import multi_gpu_model
from tensorflow.python.client import device_lib
import sys
import pandas

pretrained_weights = sys.argv[1]
if pretrained_weights == 'None':
    pretrained_weights = None

n_gpus = len([x.name for x in device_lib.list_local_devices() if x.device_type == 'GPU'])

# Directoly/folder prepration
root_folder = './'
#test_img = root_folder + 'test_img/'
test_img = sys.argv[2]
#test_results = root_folder + '/test_results/'
test_results = sys.argv[3]

patch_root = root_folder + '/patch/'
patch_pred = patch_root + '/patch_pred/'

timestamp =  str(datetime.datetime.now())

patch_size = int(sys.argv[4]) # multiples of 2^depth
#resolution = 0.298 # Resampling the image. Original image resolution is about 0.3 m/pixel. Oversampling will be needed for balancing building and nonbuilding segments.

import segmentation_models as sm
model = sm.Unet('resnet34', classes=1, activation='sigmoid')

model.summary()

if pretrained_weights is not None:
    model.load_weights(pretrained_weights) # Loading pretrained model.

if n_gpus > 1:
    model = multi_gpu_model(model, gpus=n_gpus)

all_full_ext = os.listdir(test_img)
for fe in all_full_ext:
#    patch_root = './patch_test/' #tempfile.mkdtemp()
    patch_root = tempfile.mkdtemp()
    patch_img = patch_root + '/patch_relief/'
    patch_ann = patch_root + '/patch_mask/'
    patch_pred = patch_root + '/patch_pred/'
    patch_prob = patch_root + '/patch_prob/'

    os.makedirs(patch_root, exist_ok=True)
    os.makedirs(patch_img, exist_ok=True)
    os.makedirs(patch_ann, exist_ok=True)
    os.makedirs(patch_pred, exist_ok=True)
    os.makedirs(patch_prob, exist_ok=True)
    
    os.system("bash ./prep_test_set.sh " + test_img+ "/"+fe + " " + patch_img + " " + patch_pred + " " + str(patch_size))

    all_files = os.listdir(patch_img)
    for f in all_files:
        if f.endswith(".tif"):
            raw = Image.open(patch_img + '/' + f)
            raw = np.array(raw)
            raw = np.array(raw)/255.
            raw = raw[:,:,0:3]

            pred = model.predict(np.expand_dims(raw, 0))
            pred = pred.astype(np.float32).reshape([patch_size,patch_size])
            im = Image.fromarray(pred)
            im.save(patch_prob + '/' + f + '.prob.tif')

            pred[pred >= 0.5] = 1
            pred[pred < 0.5] = 0
            pred = pred.astype(np.uint8).reshape([patch_size,patch_size])
            im = Image.fromarray(pred)
            im.save(patch_pred + '/' + f + '.pred.tif')

    os.system("bash ./merge_patch_pred.sh "+ fe + " " + patch_pred + " " + patch_prob + " " + test_results)
    shutil.rmtree(patch_root)
