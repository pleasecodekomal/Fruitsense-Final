from tensorflow.keras.models import load_model

models = {
    "apple": "models/apple/model.h5",
    "banana": "models/banana/model.h5",
    "orange": "models/orange/model.h5",
}

for name, path in models.items():
    model = load_model(path, compile=False)
    print(name, "→", model.input_shape)