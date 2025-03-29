# TensorFlow Lite Models

This directory is where you should place your TensorFlow Lite models for on-device inference.

## Required Files

1. `model.tflite` - Your trained TensorFlow Lite model
2. `labels.txt` - A text file with one label per line corresponding to the output classes of your model

## How to Add Your Own Model

1. Train a model using TensorFlow or download a pre-trained model
2. Convert it to TensorFlow Lite format (.tflite)
3. Place the .tflite file in this directory and rename it to `model.tflite`
4. Create a `labels.txt` file with your class labels (one per line)
5. Update the `_modelInputSize` variable in the ScanScreen class if your model requires a different input size

## Resources

- [TensorFlow Lite for Flutter](https://www.tensorflow.org/lite/guide/flutter)
- [Pre-trained models for TensorFlow Lite](https://www.tensorflow.org/lite/models)
- [Custom model training](https://www.tensorflow.org/lite/models/convert/convert_models)

## Note

For the app to work offline, you need a properly trained model that can recognize the types of activities your app is designed to detect. The placeholders included won't actually perform recognition until replaced with real models. 