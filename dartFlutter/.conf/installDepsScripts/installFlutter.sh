#!/bin/bash

# Flutter SDK location
FLUTTER_DIR="/opt/flutter"

# Check if Flutter exists
if [ -d "$FLUTTER_DIR" ]; then
    echo "Flutter SDK already exists at $FLUTTER_DIR"
else
    echo "Flutter SDK not found at $FLUTTER_DIR"
    echo "Please extract the Flutter SDK to /opt first."
    exit 1
fi

# Set ownership and permissions
echo "Setting permissions for $FLUTTER_DIR..."
sudo chown -R "$USER:$USER" "$FLUTTER_DIR"
sudo chmod -R 755 "$FLUTTER_DIR"

echo "Flutter SDK is installed at:"
echo "  $FLUTTER_DIR"

echo "No PATH changes were made."
echo "Run Flutter manually with:"
echo "  /opt/flutter/bin/flutter --version"
echo "  /opt/flutter/bin/flutter doctor"

echo "Setup complete."