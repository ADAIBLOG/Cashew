import csv
import json
import os
import requests

dir_path = os.path.dirname(os.path.realpath(__file__)) + "\\"

csv_file_name = 'translations.csv'



# Read the CSV file
with open(dir_path + csv_file_name, 'r', encoding='utf-8') as file:
    reader = csv.reader(file)
    rows = list(reader)

# Get the header row containing the languages
languages = rows[0][1:]

# Generate the output files
current_lang_index = 1
for lang in languages:
    print("Current Language - " + lang)
    current_lang_data = {}
    for row in rows[2:]:
        if row[current_lang_index]=="": continue
        current_lang_data[row[0]] = row[current_lang_index]

    # Write the JSON file
    with open(dir_path + "generated/" + lang + ".json", 'w', encoding='utf-8') as file:
        json.dump(current_lang_data, file, indent=2, ensure_ascii=False)

    current_lang_index += 1

print("Done!")
