'''
pip install nbconvert
'''
import os
import subprocess

def convert_ipynb_to_py_in_current_folder():
    """
    Converts all .ipynb files in the current folder to .py files.
    Does not include subfolders.
    """
    # Get a list of all files in the current directory
    try:
        files = [f for f in os.listdir('.') if os.path.isfile(f)]
    except OSError as e:
        print(f"Error accessing current directory: {e}")
        return

    ipynb_files_found = False
    for filename in files:
        if filename.endswith(".ipynb"):
            ipynb_files_found = True
            py_filename = filename[:-6] + ".py" # Change extension from .ipynb to .py
            print(f"Converting {filename} to {py_filename}...")
            try:
                # Use jupyter nbconvert command
                subprocess.run(
                    ["jupyter", "nbconvert", "--to", "script", filename],
                    check=True,
                    capture_output=True, # Capture stdout and stderr
                    text=True # Decode output as text
                )
                print(f"Successfully converted {filename} to {py_filename}")
            except subprocess.CalledProcessError as e:
                print(f"Error converting {filename}:")
                print(f"Stderr: {e.stderr}")
            except FileNotFoundError:
                print("Error: 'jupyter' command not found. Make sure Jupyter is installed and in your PATH.")
                return
            except Exception as e:
                print(f"An unexpected error occurred while converting {filename}: {e}")

    if not ipynb_files_found:
        print("No .ipynb files found in the current directory.")

if __name__ == "__main__":
    convert_ipynb_to_py_in_current_folder()
