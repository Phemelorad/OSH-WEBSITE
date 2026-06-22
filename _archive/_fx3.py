import sys
path = "accident-entries.html"
with open(path, "r", encoding="utf-8") as f:
    c = f.read()
print("", len(c))
