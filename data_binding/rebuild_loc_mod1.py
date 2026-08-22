import os
import re
import codecs

def rebuild_consolidated_localization(mod_root, target_file):
    # This will hold the final lines to write
    final_content = []
    
    # We want to preserve the original header if possible, or create a clean one
    final_content.append("l_english:")
    final_content.append("### ========================================")
    final_content.append("### SKONESTER CHEAT MENU CONSOLIDATED LOCALIZATION")
    final_content.append("### ========================================")
    
    existing_keys = set(["l_english"]) # Lowercase keys to track duplicates
    
    # Regex to identify key lines
    key_pattern = re.compile(r'^\s*([\w\.\-]+):(\d*)\s*')
    
    processed_files = 0
    total_keys_added = 0
    
    # Scan mod1 localization/english recursively
    source_dir = os.path.join(mod_root, "localization", "english")
    
    for root, dirs, files in os.walk(source_dir):
        # Sort files to maintain some consistency in order
        files.sort()
        for file in files:
            if file.endswith('.yml'):
                file_path = os.path.join(root, file)
                if os.path.abspath(file_path) == os.path.abspath(target_file):
                    continue
                
                try:
                    content = None
                    for encoding in ['utf-8-sig', 'utf-8', 'utf-16']:
                        try:
                            with codecs.open(file_path, 'r', encoding) as f:
                                content = f.readlines()
                                break
                        except:
                            continue
                    
                    if content:
                        processed_files += 1
                        file_header_added = False
                        
                        for line in content:
                            match = key_pattern.match(line)
                            if match:
                                key_raw = match.group(1)
                                key_low = key_raw.lower()
                                
                                if key_low not in existing_keys:
                                    if not file_header_added:
                                        final_content.append(f"\n ### From: {os.path.relpath(file_path, source_dir)}")
                                        file_header_added = True
                                    
                                    final_content.append(line.rstrip())
                                    existing_keys.add(key_low)
                                    total_keys_added += 1
                except Exception as e:
                    print(f"Error processing {file}: {e}")

    # Write the new file (overwriting the old one)
    # CK3 requires UTF-8 with BOM for localization files
    with codecs.open(target_file, 'w', 'utf-8-sig') as f:
        f.write("\n".join(final_content))
        f.write("\n")

    print(f"Rebuilt with {total_keys_added} keys from {processed_files} files in mod1.")
    print(f"Total lines in new file: {len(final_content)}")

if __name__ == "__main__":
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # Assuming the script is in mod1/data_binding, the root is two levels up
    mod_root_guess = os.path.abspath(os.path.join(script_dir, ".."))
    
    # Target file is in the same folder as the script
    target = os.path.join(script_dir, "fully_consolidated_l_english.yml")
    
    print(f"Mod Root: {mod_root_guess}")
    print(f"Target: {target}")
    
    rebuild_consolidated_localization(mod_root_guess, target)
