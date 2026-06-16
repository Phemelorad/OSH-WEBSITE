import os
path = "C:/Users/26772/osh website/case-tracking.html"
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
print('Read', len(content), 'bytes')
print('Ends with:', repr(content[-50:]))
