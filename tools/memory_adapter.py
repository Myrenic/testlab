#!/usr/bin/env python3
"""
Simple memory adapter using SQLite. Stores memory items with metadata and supports basic query, verify and expire operations.
"""
import sqlite3
import json
import time
from typing import List, Dict, Any

DB = __file__.replace('memory_adapter.py','memory.db')

def init_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT,
        content TEXT,
        metadata TEXT,
        created_at INTEGER,
        verified INTEGER DEFAULT 0,
        expires_at INTEGER
    )''')
    conn.commit()
    conn.close()

def add_memory(key: str, content: str, metadata: Dict[str, Any]=None, ttl_seconds: int=None) -> int:
    init_db()
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    meta = json.dumps(metadata or {})
    created = int(time.time())
    expires_at = created + ttl_seconds if ttl_seconds else None
    c.execute('INSERT INTO memories (key,content,metadata,created_at,expires_at) VALUES (?,?,?,?,?)',
              (key, content, meta, created, expires_at))
    conn.commit()
    rowid = c.lastrowid
    conn.close()
    return rowid

def query_memories(q: str, top_k: int=5) -> List[Dict[str, Any]]:
    init_db()
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    # naive search: match key or content
    q_like = f"%{q}%"
    c.execute('SELECT id,key,content,metadata,created_at,verified,expires_at FROM memories WHERE (key LIKE ? OR content LIKE ?) ORDER BY created_at DESC LIMIT ?', (q_like,q_like,top_k))
    rows = c.fetchall()
    conn.close()
    results = []
    for r in rows:
        results.append({
            'id': r[0], 'key': r[1], 'content': r[2], 'metadata': json.loads(r[3] or '{}'),
            'created_at': r[4], 'verified': bool(r[5]), 'expires_at': r[6]
        })
    return results

def verify_memory(mem_id: int, verified: bool=True):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute('UPDATE memories SET verified=? WHERE id=?', (1 if verified else 0, mem_id))
    conn.commit()
    conn.close()

def expire_memory(mem_id: int):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute('DELETE FROM memories WHERE id=?', (mem_id,))
    conn.commit()
    conn.close()

if __name__ == '__main__':
    # quick demo
    init_db()
    print('Memory adapter ready at', DB)
