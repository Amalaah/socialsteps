import tensorflow as tf
import numpy as np

# Generate smarter synthetic data
X = []
y = []

for _ in range(2000):
    emotion = np.random.rand()
    focus = np.random.rand()
    puzzle = np.random.rand()
    color = np.random.rand()

    emotionTrend = np.random.uniform(-0.3, 0.3)
    focusTrend = np.random.uniform(-0.3, 0.3)

    avgTime = np.random.rand()
    streak = np.random.rand()

    # Score logic
    scores = [
        (1-emotion) + max(0, -emotionTrend),
        (1-focus) + max(0, -focusTrend),
        (1-puzzle),
        (1-color)
    ]

    target = np.argmax(scores)

    X.append([
        emotion,
        focus,
        puzzle,
        color,
        emotionTrend,
        focusTrend,
        avgTime,
        streak
    ])

    y.append(target)

X = np.array(X)
y = np.array(y)

model = tf.keras.Sequential([
    tf.keras.layers.Dense(32, activation='relu', input_shape=(8,)),
    tf.keras.layers.Dense(16, activation='relu'),
    tf.keras.layers.Dense(4, activation='softmax')
])

model.compile(
    optimizer='adam',
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

model.fit(X, y, epochs=20)

converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

with open("recommendation_model.tflite", "wb") as f:
    f.write(tflite_model)

print("Smarter model trained and converted successfully!")