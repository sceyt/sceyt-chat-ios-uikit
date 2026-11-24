#!/usr/bin/env python3
"""Fails when Swift files under the given paths outgrow their limits.

    scripts/check_code_size.py [--max-file N] [--max-function N] [--max-depth N] PATH...

Limits (defaults): a file is at most 600 lines, a function (or init, closure-free body of a
`func`/`init`/accessor) at most 60, and code nests at most 5 blocks deep inside a function.
Comments and blank lines count toward file length but not function length. No dependencies,
so it runs the same on a laptop and in CI.
"""
import argparse
import pathlib
import re
import sys

DECL = re.compile(r'^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|open|internal|private|fileprivate|final|override|static|class|nonisolated|mutating|required|convenience|@objc|@discardableResult)\s+)*(func\s+[\w<>`]+|init[?!]?|deinit)\b')


def code_lines(lines):
    """Each line with string literals and comments blanked, so braces inside them don't count."""
    out = []
    in_block = False
    for line in lines:
        s = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
        if in_block:
            if '*/' in s:
                s = s.split('*/', 1)[1]
                in_block = False
            else:
                out.append('')
                continue
        if '/*' in s and '*/' not in s.split('/*', 1)[1]:
            s = s.split('/*', 1)[0]
            in_block = True
        s = re.sub(r'/\*.*?\*/', '', s)
        s = s.split('//', 1)[0]
        out.append(s)
    return out


def check(path, max_file, max_function, max_depth):
    lines = path.read_text().split('\n')
    problems = []
    if len(lines) > max_file:
        problems.append(f'{path}: {len(lines)} lines (limit {max_file})')
    code = code_lines(lines)
    i = 0
    while i < len(code):
        m = DECL.match(code[i])
        if not m:
            i += 1
            continue
        start = i
        # the body opens at the first '{' after the declaration (signatures may wrap)
        j = i
        while j < len(code) and '{' not in code[j]:
            if code[j].strip().endswith('}') or (j > i and DECL.match(code[j])):
                break
            j += 1
        if j >= len(code) or '{' not in code[j]:
            i += 1
            continue
        depth = 0
        deepest = 0
        body = 0
        k = j
        while k < len(code):
            for ch in code[k]:
                if ch == '{':
                    depth += 1
                    deepest = max(deepest, depth)
                elif ch == '}':
                    depth -= 1
            if k > j and code[k].strip():
                body += 1
            if depth == 0:
                break
            k += 1
        name = m.group(1)
        if body - 1 > max_function:
            problems.append(f'{path}:{start + 1}: `{name}` body is {body - 1} lines (limit {max_function})')
        if deepest - 1 > max_depth:
            problems.append(f'{path}:{start + 1}: `{name}` nests {deepest - 1} blocks deep (limit {max_depth})')
        i = k + 1
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--max-file', type=int, default=600)
    parser.add_argument('--max-function', type=int, default=60)
    parser.add_argument('--max-depth', type=int, default=5)
    parser.add_argument('paths', nargs='+')
    args = parser.parse_args()
    files = []
    for p in args.paths:
        p = pathlib.Path(p)
        files += sorted(p.rglob('*.swift')) if p.is_dir() else [p]
    problems = [x for f in files for x in check(f, args.max_file, args.max_function, args.max_depth)]
    for problem in problems:
        print(problem)
    print(f'{len(files)} file(s) checked, {len(problems)} problem(s)')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
