import os
import shutil
from pathlib import Path

def setup_directories(base_path: Path, folder_names: list[str]) -> None:
    """Ensure that sorting subdirectories exist within the target path."""
    for folder in folder_names:
        folder_path = base_path / folder
        if not folder_path.exists():
            folder_path.mkdir(parents=True, exist_ok=True)
            print(f"Created directory: {folder_path}")

def sort_files(target_directory: str = "./unsorted_files") -> None:
    """Scans a target directory and sorts files into categorized subfolders based on extension."""
    path = Path(target_directory)
    
    if not path.exists():
        print(f"Error: The directory '{path}' does not exist. Please create it and add some test files.")
        return

    # Define categories and their matching file extensions
    categories = {
        'excel_files': ['.xlsx', '.xls', '.csv'],
        'image_files': ['.jpg', '.jpeg', '.png', '.gif'],
        'text_files': ['.txt', '.doc', '.docx', '.pdf'],
        'py_files': ['.py', '.ipynb']
    }

    # Setup the subfolders
    setup_directories(path, list(categories.keys()))

    # Get all files in the target directory (excluding directories)
    files = [item for item in path.iterdir() if item.is_file()]
    
    if not files:
        print("No files found to sort.")
        return

    moved_count = 0
    for file_path in files:
        file_extension = file_path.suffix.lower()
        
        # Match file extension to category
        for folder_name, extensions in categories.items():
            if file_extension in extensions:
                destination = path / folder_name / file_path.name
                
                # Move only if it doesn't already exist in destination
                if not destination.exists():
                    shutil.move(str(file_path), str(destination))
                    print(f"Moved: {file_path.name} -> {folder_name}/")
                    moved_count += 1
                break

    print(f"\nSorting complete! Successfully sorted {moved_count} file(s).")

if __name__ == "__main__":
    target_folder = "./path/to/your/folder"
    sort_files(target_folder)