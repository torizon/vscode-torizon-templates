import os
from pathlib import Path
import sys
import hashlib

def hash_file(filepath, algorithm='sha256'):
    hasher = hashlib.new(algorithm)
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            hasher.update(chunk)
    return hasher.hexdigest()

# Retrieve environment variables
login = os.getenv('QT_LICENSE_LOGIN')
password = os.getenv('QT_LICENSE_PASSWORD')

# Define output path (adjust this to fit your workspaceFolder if running standalone)
output_path = Path.cwd() / ".conf" / "qt6-enterprise" / "qt-feed-auth.conf"

# Ensure directory exists
output_path.parent.mkdir(parents=True, exist_ok=True)

# Construct file content
if login != "" and password != "" and password != "__undefined__":
    login = f"login {login}"
    password = f"password {password}"
else:
    print("qt_license_login or qt_license_psswd environment setting is empty.")

content = f"""machine https://debian-packages.qt.io
{login}
{password}
"""

# Write to file
with open(output_path, "w") as f:
    f.write(content)

print(f"Credentials written to {output_path}")

# Save the hash of the output file, to update the Docker images every time the credentials change
hash_value = hash_file(output_path)
hash_output_path = output_path.with_suffix('.hash')

existing_hash = ""
if hash_output_path.exists():
    with open(hash_output_path, "r") as f:
        existing_hash = f.read()
    
if existing_hash != hash_value:
    with open(hash_output_path, "w") as f:
        f.write(hash_value)

print(f"Hash of qt-feed-auth written to {hash_output_path}")
