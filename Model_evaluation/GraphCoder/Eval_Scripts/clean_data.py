import json
import os

def process_jsonl(file_path, target_substring="<path", action="count"):
    """
    Processes a JSONL file to either count or delete lines where 'file_path' 
    contains the target_substring.
    
    Args:
        file_path (str): Path to the .jsonl file.
        target_substring (str): The substring to look for in the "file_path" field.
        action (str): 'count' to only count, 'delete' to create a filtered file.
    """
    count = 0
    temp_file = file_path + ".tmp"
    
    try:
        with open(file_path, 'r', encoding='utf-8') as infile:
            if action == "delete":
                outfile = open(temp_file, 'w', encoding='utf-8')
            
            for line_num, line in enumerate(infile, 1):
                if not line.strip():
                    continue
                
                try:
                    data = json.loads(line)
                    # Check if 'file_path' exists and contains the substring
                    fp_value = data.get("file_path", "")
                    
                    if target_substring in fp_value:
                        count += 1
                        # If deleting, we skip writing this line to the outfile
                        continue
                    
                    if action == "delete":
                        outfile.write(line)
                        
                except json.JSONDecodeError:
                    print(f"Skipping invalid JSON on line {line_num}")

            if action == "delete":
                outfile.close()

        if action == "count":
            print(f"Found {count} lines where 'file_path' contains '{target_substring}'.")
        
        elif action == "delete":
            # Replace original file with the filtered one
            os.replace(temp_file, file_path)
            print(f"Deleted {count} lines. File '{file_path}' has been updated.")

    except FileNotFoundError:
        print(f"Error: The file '{file_path}' was not found.")
    except Exception as e:
        print(f"An error occurred: {e}")
        if action == "delete" and os.path.exists(temp_file):
            os.remove(temp_file)

if __name__ == "__main__":
    FILENAME = 'repofuse_response.jsonl'
    
    print("Select an option:")
    print("1) Count lines containing '<path' in 'file_path'")
    print("2) Delete lines containing '<path' in 'file_path'")
    
    choice = input("Enter choice (1/2): ")
    
    if choice == '1':
        process_jsonl(FILENAME, action="count")
    elif choice == '2':
        process_jsonl(FILENAME, action="delete")
    else:
        print("Invalid choice.")