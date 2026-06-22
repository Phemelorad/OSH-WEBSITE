import sys, re
sys.stdout.reconfigure(encoding='utf-8')

path = "C:/Users/26772/osh website/accident-report.html"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

print(f"File loaded: {len(content)} chars")

# Find the start and end markers for Section 4-6
lines = content.split('
')
start_idx = None
end_idx = None

for i, line in enumerate(lines):
    if "SECTION 4" in line and "ACCIDENT" in line:
        start_idx = i
    if "SECTION 7" in line and "DANGEROUS" in line:
        end_idx = i

print(f"Start line: {start_idx}, End line: {end_idx}")

if start_idx is None or end_idx is None:
    print("ERROR: Could not find markers")
    sys.exit(1)

# Create the replacement (simplified first version)
new_html = """          <!-- ---- SECTIONS 4-6: INJURED PERSONS ---- -->
          <div class="form-card" id="accidentSection">
            <div class="section-title">4. Injured or Deceased Persons</div>
            <p class="hint" style="margin-bottom:16px">
              Add all persons injured or killed in this accident/dangerous occurrence.
            </p>
            <div id="injuredPersonsContainer"></div>
          </div>"""

# Replace the section
new_lines = lines[:start_idx] + [new_html] + lines[end_idx:]
result = '
'.join(new_lines)

with open(path, "w", encoding="utf-8") as f:
    f.write(result)

print(f"Replaced {end_idx - start_idx} lines with multi-person placeholder")
print(f"New file: {len(result)} chars")
