#!/bin/bash
# Check if flutter-elinux is available
if ! command -v flutter-elinux &> /dev/null; then
    echo "flutter-elinux not found. Installing..."

    # Clone the repository
    git clone https://github.com/flutter-elinux/flutter-elinux.git

    # Move to /opt/ with sudo
    sudo mv flutter-elinux /opt/

    # Change ownership and permissions
    sudo chown -R $USER:$USER /opt/flutter-elinux
    sudo chmod -R 755 /opt/flutter-elinux

    # Export path for current session only
    export PATH="/opt/flutter-elinux/bin:$PATH"

    echo "Installation complete."

    # Verify flutter-elinux is in PATH and run doctor
    if command -v flutter-elinux &> /dev/null; then
        flutter-elinux --version
        flutter-elinux doctor
    else
        echo "flutter-elinux installed to /opt/flutter-elinux/bin"
        echo "To use it, add the following to your PATH manually:"
        echo '  export PATH="/opt/flutter-elinux/bin:$PATH"'
    fi
else
    echo "flutter-elinux is already present"
    flutter-elinux --version
    echo "Running flutter-elinux doctor..."
    flutter-elinux doctor
fi

# Cleanup task - remove flutter-elinux folder if it exists in current directory
if [ -d "./flutter-elinux" ]; then
    echo "Cleaning up: Removing flutter-elinux folder from current directory..."
    rm -rf ./flutter-elinux
    echo "Cleanup complete."
fi