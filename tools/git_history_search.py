#!/usr/bin/env python3
"""
Search git commit messages for relevant terms. Uses `git log --all --grep`.
"""
import subprocess
import sys
from typing import List


def search_commits(repo_path: str, query: str, since_days: int=None) -> List[str]:
    cmd = ['git', '-C', repo_path, 'log', '--all', '--pretty=format:%H %ad %s', f'--grep={query}']
    if since_days:
        cmd.append(f'--since={since_days}.days')
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)
        lines = [l.strip() for l in out.splitlines() if l.strip()]
        return lines
    except subprocess.CalledProcessError:
        return []

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Usage: git_history_search.py /path/to/repo "search term"')
        sys.exit(2)
    repo = sys.argv[1]
    term = sys.argv[2]
    hits = search_commits(repo, term)
    for h in hits:
        print(h)
