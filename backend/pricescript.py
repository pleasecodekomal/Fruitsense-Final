import pandas as pd
import numpy as np
import pickle
from sklearn.preprocessing import LabelEncoder, StandardScaler
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense

# Load the processed orange dataset
df = pd.read_csv('orangee.csv')

# Initialize Preprocessing Tools
le_market = LabelEncoder()
le_variety = LabelEncoder()
scaler = StandardScaler()

# Transform Features
# These must be saved to ensure the inference script uses the same mapping
X_market = le_market.fit_transform(df['Market Name'])
X_variety = le_variety.fit_transform(df['Variety'])
X_arrivals = scaler.fit_transform(df[['Arrivals (Tonnes)']])

# Combine into input matrix
X = np.column_stack([X_market, X_variety, X_arrivals])
y = df['Modal Price (Rs./Quintal)'].values

# Define Neural Network (Regression)
model = Sequential([
    Dense(64, activation='relu', input_shape=(3,)),
    Dense(32, activation='relu'),
    Dense(16, activation='relu'),
    Dense(1) # Predicts the Modal Price
])

model.compile(optimizer='adam', loss='mse', metrics=['mae'])

# Train the model
model.fit(X, y, epochs=50, batch_size=32, verbose=1, validation_split=0.1)

# Save the Model and the Encoders
model.save('orange_price_model.h5')
helpers = {'le_market': le_market, 'le_variety': le_variety, 'scaler': scaler}
with open('orange_price_helpers.pkl', 'wb') as f:
    pickle.dump(helpers, f)