import os
import re
import codecs
from deep_translator import GoogleTranslator
import time

def translate_text(text, target_lang='tr'):
    if not text or not text.strip():
        return text
    # If it's just a reference like $key$, don't translate
    if text.startswith('$') and text.endswith('$') and text.count('$') == 2:
        return text
        
    try:
        placeholders = []
        def replace_with_placeholder(match):
            placeholders.append(match.group(0))
            return f" __PH{len(placeholders)-1}__ "
        
        patterns = [
            r'\[[\w\s|]+\]',
            r'\$[\w\.]+\$',
            r'#[A-Z!]\s*',
            r'#!',
            r'\\n',
            r'@[\w_!]+'
        ]
        
        processed_text = text
        for pattern in patterns:
            processed_text = re.sub(pattern, replace_with_placeholder, processed_text)
        
        # If nothing but placeholders left, don't translate
        if not re.sub(r'__PH\d+__|\s+', '', processed_text):
            return text

        translated = GoogleTranslator(source='en', target=target_lang).translate(processed_text)
        
        if not translated:
            return text
            
        for i, ph in enumerate(placeholders):
            translated = re.sub(rf'\s*__\s*PH\s*{i}\s*__\s*', ph, translated)
            
        return translated.strip()
    except Exception as e:
        return text

def sync_turkish(limit=100):
    en_file = os.path.join("data_binding", "fully_consolidated_l_english.yml")
    tr_dir = os.path.join("localization", "turkish")
    tr_file = os.path.join(tr_dir, "fully_consolidated_l_turkish.yml")
    
    # Read English lines
    with codecs.open(en_file, 'r', 'utf-8-sig') as f:
        en_lines = f.readlines()
    
    # Read existing Turkish translations to avoid re-translating
    translated_data = {}
    if os.path.exists(tr_file):
        with codecs.open(tr_file, 'r', 'utf-8-sig') as f:
            for line in f:
                if "# TODO" in line: continue
                m = re.search(r'^\s*([\w\.\-]+):(\d*)\s*"(.*)"', line)
                if m:
                    translated_data[m.group(1)] = m.group(3)

    new_tr_content = ["l_turkish:"]
    count = 0
    
    for i, line in enumerate(en_lines):
        if i == 0 and "l_english:" in line:
            continue
            
        m = re.search(r'^\s*([\w\.\-]+):(\d*)\s*"(.*)"', line)
        if m:
            key = m.group(1)
            version = m.group(2)
            en_value = m.group(3)
            
            # If already translated (and not identical to English, or is a reference)
            if key in translated_data and (translated_data[key] != en_value or en_value.startswith('$')):
                new_tr_content.append(f' {key}:{version} "{translated_data[key]}"')
            elif count < limit:
                print(f"[{count+1}/{limit}] Translating {key}...")
                tr_value = translate_text(en_value)
                new_tr_content.append(f' {key}:{version} "{tr_value}"')
                count += 1
                time.sleep(0.2)
            else:
                new_tr_content.append(f' {key}:{version} "{en_value}" # TODO: Translate')
        else:
            new_tr_content.append(line.rstrip())
            
    with codecs.open(tr_file, 'w', 'utf-8-sig') as f:
        f.write("\n".join(new_tr_content))
        f.write("\n")
    
    print(f"Done. Translated {count} new strings.")

if __name__ == "__main__":
    sync_turkish(limit=5000) 
