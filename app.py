from datetime import datetime, timezone
from ipaddress import ip_address
import os
import sqlite3

from fastapi import FastAPI, HTTPException, Header, Depends, Query
from pydantic import BaseModel

DB_PATH = "/data/blacklist.db"

ADMIN_TOKEN = os.getenv("ADMIN_TOKEN", "changeme-admin")
READONLY_TOKEN = os.getenv("READONLY_TOKEN", "changeme-readonly")

app = FastAPI()


class IPRequest(BaseModel):
    address: str
    reason: str = ""


def now_ts():
    return int(datetime.now(timezone.utc).timestamp())


def init_db():
    conn = sqlite3.connect(DB_PATH)

    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS blacklist (
            address TEXT PRIMARY KEY,
            version INTEGER NOT NULL,
            reason TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted INTEGER NOT NULL DEFAULT 0
        )
        """
    )

    conn.commit()
    conn.close()


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


@app.on_event("startup")
def startup():
    init_db()


def get_token(authorization: str = Header(None)):
    if not authorization:
        raise HTTPException(401, "Missing Authorization header")

    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "Invalid Authorization header")

    return authorization.split(" ", 1)[1]


def readonly_auth(token: str = Depends(get_token)):
    if token not in [ADMIN_TOKEN, READONLY_TOKEN]:
        raise HTTPException(403, "Forbidden")


def admin_auth(token: str = Depends(get_token)):
    if token != ADMIN_TOKEN:
        raise HTTPException(403, "Forbidden")


@app.get("/")
def root():
    raise HTTPException(
        status_code=404,
        detail="Cannot GET /"
    )


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/list", dependencies=[Depends(readonly_auth)])
def blacklist():
    conn = get_db()

    rows = conn.execute(
        """
        SELECT *
        FROM blacklist
        WHERE deleted = 0
        ORDER BY updated_at DESC
        """
    ).fetchall()

    conn.close()

    return [
        {
            "address": row["address"],
            "version": row["version"],
            "reason": row["reason"],
            "timestamp": datetime.fromtimestamp(
                row["created_at"],
                tz=timezone.utc
            ).isoformat()
        }
        for row in rows
    ]


@app.get("/changes", dependencies=[Depends(readonly_auth)])
def changes(
    since: int = Query(
        ...,
        description="Unix timestamp"
    )
):
    conn = get_db()

    rows = conn.execute(
        """
        SELECT *
        FROM blacklist
        WHERE updated_at > ?
        ORDER BY updated_at ASC
        """,
        (since,)
    ).fetchall()

    conn.close()

    return [
        {
            "address": row["address"],
            "version": row["version"],
            "reason": row["reason"],
            "deleted": bool(row["deleted"]),
            "created_at": row["created_at"],
            "updated_at": row["updated_at"]
        }
        for row in rows
    ]


@app.post("/banip", dependencies=[Depends(admin_auth)])
def ban_ip(req: IPRequest):
    try:
        ip = ip_address(req.address)

    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Invalid IP address"
        )

    ts = now_ts()

    conn = get_db()

    existing = conn.execute(
        """
        SELECT address
        FROM blacklist
        WHERE address = ?
        """,
        (str(ip),)
    ).fetchone()

    if existing:
        conn.execute(
            """
            UPDATE blacklist
            SET
                deleted = 0,
                reason = ?,
                updated_at = ?
            WHERE address = ?
            """,
            (
                req.reason,
                ts,
                str(ip)
            )
        )

    else:
        conn.execute(
            """
            INSERT INTO blacklist (
                address,
                version,
                reason,
                created_at,
                updated_at,
                deleted
            )
            VALUES (?, ?, ?, ?, ?, 0)
            """,
            (
                str(ip),
                ip.version,
                req.reason,
                ts,
                ts
            )
        )

    conn.commit()
    conn.close()

    return {
        "status": "success",
        "address": str(ip)
    }


@app.post("/unbanip", dependencies=[Depends(admin_auth)])
def unban_ip(req: IPRequest):
    ts = now_ts()

    conn = get_db()

    cursor = conn.execute(
        """
        UPDATE blacklist
        SET
            deleted = 1,
            updated_at = ?
        WHERE address = ?
        """,
        (
            ts,
            req.address
        )
    )

    conn.commit()

    affected = cursor.rowcount

    conn.close()

    if affected == 0:
        raise HTTPException(
            status_code=404,
            detail="IP not found"
        )

    return {
        "status": "success",
        "address": req.address
    }
