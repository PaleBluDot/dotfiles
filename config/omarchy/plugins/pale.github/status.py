#!/usr/bin/env python3
"""Print GitHub status for the bar widget as JSON, using the gh CLI."""
import json, os, re, shutil, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

LIMIT = 10
LOCAL_ROOT = os.path.expanduser("~/Projects/github.com")

def local_repos():
    """Git repos laid out as ~/Projects/github.com/<org>/<repo>."""
    count = 0
    try:
        for org in os.scandir(LOCAL_ROOT):
            if not org.is_dir() or org.name.startswith("."):
                continue
            for repo in os.scandir(org.path):
                if repo.is_dir() and os.path.exists(os.path.join(repo.path, ".git")):
                    count += 1
    except OSError:
        pass
    return {"count": count, "path": LOCAL_ROOT}

def remote_repos():
    """Repos you own plus repos in orgs you belong to."""
    out = gh("api", "--paginate", "user/repos?affiliation=owner,organization_member&per_page=100", "--jq", ".[].full_name")
    return len([l for l in out.splitlines() if l.strip()])

def gh(*args):
    p = subprocess.run(["gh", *args], capture_output=True, text=True, timeout=25)
    if p.returncode != 0:
        raise RuntimeError((p.stderr or p.stdout).strip().splitlines()[-1] if (p.stderr or p.stdout).strip() else "gh failed")
    return p.stdout

def html_url(api_url, repo_html):
    if not api_url:
        return repo_html
    m = re.match(r"https://api\.github\.com/repos/([^/]+/[^/]+)/(pulls|issues|commits|releases)/(.+)$", api_url)
    if not m:
        return repo_html
    repo, kind, rest = m.groups()
    kind = {"pulls": "pull", "issues": "issues", "commits": "commit", "releases": "releases"}[kind]
    if kind == "releases":
        return f"https://github.com/{repo}/releases"
    return f"https://github.com/{repo}/{kind}/{rest}"

def notifications():
    data = json.loads(gh("api", "notifications?per_page=50"))
    items = [{
        "title": n.get("subject", {}).get("title", ""),
        "meta": f'{n.get("repository", {}).get("full_name", "")} · {n.get("subject", {}).get("type", "")} · {n.get("reason", "").replace("_", " ")}',
        "url": html_url(n.get("subject", {}).get("url"), n.get("repository", {}).get("html_url", "https://github.com/notifications")),
    } for n in data]
    return {"count": len(data), "capped": len(data) >= 50, "items": items[:LIMIT],
            "more": "https://github.com/notifications"}

def search(query, more):
    data = json.loads(gh("api", "-X", "GET", "search/issues", "-f", f"q={query}", "-f", f"per_page={LIMIT}", "-f", "sort=updated"))
    items = [{
        "title": i.get("title", ""),
        "meta": f'{i.get("repository_url", "").split("/repos/")[-1]} #{i.get("number", "")}',
        "url": i.get("html_url", more),
    } for i in data.get("items", [])]
    return {"count": int(data.get("total_count", 0)), "capped": False, "items": items, "more": more}

def main():
    out = {"installed": shutil.which("gh") is not None, "authenticated": False, "user": "", "sections": {}, "error": "",
           "local": local_repos(), "remote": {"count": 0, "url": "https://github.com"}}
    if not out["installed"]:
        print(json.dumps(out)); return
    try:
        out["user"] = gh("api", "user", "--jq", ".login").strip()
        out["authenticated"] = True
    except Exception:
        print(json.dumps(out)); return
    jobs = {
        "notifications": lambda: notifications(),
        "reviews": lambda: search("is:open is:pr archived:false review-requested:@me", "https://github.com/pulls/review-requested"),
        "mine": lambda: search("is:open is:pr archived:false author:@me", "https://github.com/pulls"),
        "issues": lambda: search("is:open is:issue archived:false assignee:@me", "https://github.com/issues/assigned"),
        "remote": lambda: remote_repos(),
    }
    with ThreadPoolExecutor(max_workers=4) as ex:
        futures = {k: ex.submit(f) for k, f in jobs.items()}
        for k, f in futures.items():
            try:
                if k == "remote":
                    out["remote"] = {"count": f.result(), "url": f"https://github.com/{out['user']}"}
                    continue
                out["sections"][k] = f.result()
            except Exception as e:
                if k == "remote":
                    out["remote"] = {"count": 0, "url": f"https://github.com/{out['user']}", "error": str(e)[:160]}
                    continue
                out["sections"][k] = {"count": 0, "capped": False, "items": [], "more": "https://github.com", "error": str(e)[:160]}
                out["error"] = out["error"] or str(e)[:160]
    print(json.dumps(out))

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(json.dumps({"installed": True, "authenticated": False, "user": "", "sections": {}, "error": str(e)[:160]}))
