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

    # Add to PATH in .bashrc
    echo '' >> "$HOME/.bashrc"  # Add a newline for clarity
    echo '# Add flutter-elinux to PATH' >> "$HOME/.bashrc"
    echo 'export PATH="/opt/flutter-elinux/bin:$PATH"' >> "$HOME/.bashrc"

    # Verify if the path was added
    if grep -q "/opt/flutter-elinux/bin" "$HOME/.bashrc"; then
        echo "Successfully added flutter-elinux to PATH in .bashrc"
    else
        echo "Failed to add flutter-elinux to PATH. Please add manually:"
        echo 'export PATH="/opt/flutter-elinux/bin:$PATH"'
    fi

    # Source .bashrc
    echo "Updating current session..."
    source "$HOME/.bashrc"

    # Export path for current session
    export PATH="/opt/flutter-elinux/bin:$PATH"

    echo "Installation complete. Running flutter-elinux doctor..."

    # Verify flutter-elinux is in PATH
    echo "Verifying PATH..."
    echo $PATH | grep "flutter-elinux"

    # Run flutter-elinux doctor
    if command -v flutter-elinux &> /dev/null; then
        flutter-elinux --version
        flutter-elinux doctor
    else
        echo "Please run the following commands manually:"
        echo "source ~/.bashrc"
        echo "flutter-elinux doctor"
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
