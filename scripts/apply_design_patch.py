#!/usr/bin/env python3
"""
Apply design document patch to rails8-authentication-migration.md
Reads the original file and the patch file, then applies all changes.
"""

import re

def main():
    # Read original file
    with open('docs/designs/rails8-authentication-migration.md', 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Read patch file
    with open('docs/designs/rails8-authentication-migration.md.patch', 'r', encoding='utf-8') as f:
        patch_content = f.read()

    # Parse patch sections
    patches = []

    # Update metadata (iteration 1 -> 2)
    for i, line in enumerate(lines):
        if 'iteration: 1' in line:
            lines[i] = line.replace('iteration: 1', 'iteration: 2')

    # Extract sections to insert from patch
    insert_sections = {
        '2.2.5': extract_section(patch_content, 'INSERT AFTER SECTION 2.2', '## INSERT AFTER SECTION 3.3'),
        '3.3.1': extract_section(patch_content, 'INSERT AFTER SECTION 3.3', '## INSERT AFTER SECTION 4.1.3'),
        '4.1.4': extract_section(patch_content, 'INSERT AFTER SECTION 4.1.3', '## UPDATE SECTION 4.2'),
        '6.5': extract_section(patch_content, 'INSERT AFTER SECTION 6.4', '## INSERT AFTER SECTION 8'),
        '8.7': extract_section(patch_content, 'INSERT AFTER SECTION 8', '## INSERT AFTER SECTION 9.5'),
        '9.6': extract_section(patch_content, 'INSERT AFTER SECTION 9.5', '## INSERT AFTER SECTION 11'),
        '11.5': extract_section(patch_content, 'INSERT AFTER SECTION 11', '## INSERT NEW SECTION 13'),
        '13': extract_section(patch_content, '## INSERT NEW SECTION 13', None),
    }

    # Find insertion points
    insertion_points = find_insertion_points(lines)

    # Insert sections in reverse order (to maintain line numbers)
    for section_num in reversed(sorted(insert_sections.keys(), key=custom_sort)):
        if section_num in insertion_points:
            idx = insertion_points[section_num]
            content = insert_sections[section_num]
            if content:
                lines.insert(idx, content + '\n')

    # Update Section 4.2 (Final Schema)
    update_section_4_2(lines, patch_content)

    # Write updated file
    with open('docs/designs/rails8-authentication-migration.md', 'w', encoding='utf-8') as f:
        f.writelines(lines)

    print("✅ Design document updated successfully!")
    print(f"   Original lines: {len(open('docs/designs/rails8-authentication-migration-v1.md').readlines())}")
    print(f"   Updated lines: {len(lines)}")

def extract_section(patch, start_marker, end_marker):
    """Extract content between two markers in the patch file"""
    start_idx = patch.find(start_marker)
    if start_idx == -1:
        return ""

    if end_marker:
        end_idx = patch.find(end_marker, start_idx)
        if end_idx == -1:
            content = patch[start_idx:]
        else:
            content = patch[start_idx:end_idx]
    else:
        content = patch[start_idx:]

    # Extract actual content (skip the marker line)
    lines = content.split('\n')
    # Skip first line (marker) and any empty lines
    content_lines = []
    skip_marker = True
    for line in lines:
        if skip_marker and (line.startswith('##') or not line.strip()):
            continue
        skip_marker = False
        content_lines.append(line)

    return '\n'.join(content_lines).strip()

def find_insertion_points(lines):
    """Find line numbers where sections should be inserted"""
    points = {}

    for i, line in enumerate(lines):
        # Look for section headers
        if line.startswith('### 2.3'):  # After 2.2
            points['2.2.5'] = i
        elif line.startswith('### 3.4') or line.startswith('## 4.'):  # After 3.3
            if '3.3.1' not in points:
                points['3.3.1'] = i
        elif line.startswith('### 4.2'):  # After 4.1
            points['4.1.4'] = i
        elif line.startswith('### 6.5') or line.startswith('## 7.'):  # After 6.4
            if '6.5' not in points:
                points['6.5'] = i
        elif line.startswith('## 9.'):  # After 8
            if '8.7' not in points:
                points['8.7'] = i
        elif line.startswith('### 9.6') or line.startswith('## 10.'):  # After 9.5
            if '9.6' not in points:
                points['9.6'] = i
        elif line.startswith('## 12.'):  # After 11
            points['11.5'] = i
        elif line.strip() == '' and i == len(lines) - 1:  # End of file
            points['13'] = i

    return points

def update_section_4_2(lines, patch):
    """Update Section 4.2 with new schema including MFA and OAuth fields"""
    # Find Section 4.2
    for i, line in enumerate(lines):
        if line.startswith('### 4.2 Final Schema'):
            # Look for the create_table block
            start_idx = i
            end_idx = i
            for j in range(i, min(i + 100, len(lines))):
                if '```ruby' in lines[j]:
                    start_idx = j
                if 'end' in lines[j] and start_idx < j:
                    end_idx = j + 2  # Include ``` closing
                    break

            # Extract new schema from patch
            new_schema = extract_section(patch, '## UPDATE SECTION 4.2', '## INSERT AFTER SECTION 6.4')
            if new_schema:
                # Replace old schema
                del lines[i:end_idx]
                lines.insert(i, new_schema + '\n\n')
            break

def custom_sort(section_num):
    """Custom sort for section numbers like '2.2.5', '3.3.1', '13'"""
    parts = section_num.split('.')
    return tuple(int(p) if p.isdigit() else 999 for p in parts)

if __name__ == '__main__':
    main()
