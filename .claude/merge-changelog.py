import subprocess, pathlib

repo = r'C:\Users\Xps13\RiderProjects\ai-agent-kit'
# Get ours (master): has docs(claude) entry at top
ours = subprocess.check_output(['git', '-C', repo, 'show', ':2:CHANGELOG.md'], encoding='utf-8')
# Get theirs (release): has feat(release) entry at top
theirs = subprocess.check_output(['git', '-C', repo, 'show', ':3:CHANGELOG.md'], encoding='utf-8')

# Extract the feat(release) block from theirs
theirs_lines = theirs.split('\n')
release_entry_lines = []
in_release = False
for line in theirs_lines:
    if 'feat(release)' in line and line.startswith('- **'):
        in_release = True
    if in_release:
        if line.startswith('- **') and 'feat(release)' not in line:
            break
        release_entry_lines.append(line)
release_entry = '\n'.join(release_entry_lines).rstrip()

# Insert the release entry before the docs(claude) entry in ours
docs_marker = '- **`docs(claude)`'
merged = ours.replace(docs_marker, release_entry + '\n\n' + docs_marker, 1)

pathlib.Path(repo + r'\CHANGELOG.md').write_text(merged, encoding='utf-8')
print('OK - lines:', merged.count('\n'))
