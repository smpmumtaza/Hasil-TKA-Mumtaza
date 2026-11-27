"""Generate and stage Try Out PDFs before publishing the corresponding results."""

import json
import os
import re
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime
from decimal import Decimal
from threading import Lock
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from uuid import uuid4
from zoneinfo import ZoneInfo

import fitz
from flask import Flask, jsonify, request

DRIVE = "https://www.googleapis.com/drive/v3/files"
UPLOAD = "https://www.googleapis.com/upload/drive/v3/files"
PDF_LOCK = Lock()
STUDENT_FIELDS = ("bahasa_indonesia", "matematika", "rata_rata")


def validate_rows(rows):
    if not isinstance(rows, list) or not 1 <= len(rows) <= 2000:
        raise ValueError("Unggah 1 sampai 2.000 siswa.")
    seen = set()
    for index, row in enumerate(rows, 1):
        try:
            nisn = row["nisn"]
            if not re.fullmatch(r"[0-9]{10}", nisn) or nisn in seen:
                raise ValueError
            seen.add(nisn)
            if not all(isinstance(row[k], str) and row[k].strip()
                       and not re.search(r"[\x00-\x1f]", row[k])
                       and len(row[k]) <= limit
                       for k, limit in (("nama", 200), ("kelas", 40))):
                raise ValueError
            birth = row["tanggal_lahir"]
            if date.fromisoformat(birth).isoformat() != birth:
                raise ValueError
            for field in STUDENT_FIELDS:
                value = row[field]
                if type(value) not in (int, float) or not 0 <= value <= 100:
                    raise ValueError
        except (KeyError, TypeError, ValueError):
            raise ValueError(f"Periksa nama, kelas, NISN, tanggal lahir dan nilai pada baris {index}.") from None


def pdf_bytes(template, row):
    """The private template has five blank fields in the school's approved layout."""
    def format_grade(value):
        return format(Decimal(str(value)).normalize(), "f").replace(".", ",")

    fields = (
        (216.10, 230.70, ": " + row["nama"], False),
        (216.10, 251.40, ": " + row["kelas"], False),
        (303.65, 339.90, format_grade(row["matematika"]), True),
        (303.65, 371.20, format_grade(row["bahasa_indonesia"]), True),
        (444.66, 356.00, format_grade(row["rata_rata"]), True),
    )
    with PDF_LOCK, fitz.open(stream=template, filetype="pdf") as document:
        page = document[0]
        for x, y, value, centered in fields:
            font = "tibo" if centered else "tiro"
            width = fitz.get_text_length(value, fontname=font, fontsize=12)
            size = min(12, 300 * 12 / max(width, 1))
            page.insert_text((x - width * size / 24 if centered else x, y),
                             value, fontname=font, fontsize=size)
        return document.tobytes(garbage=4, deflate=True)


def send(url, *, method="GET", headers=None, body=None):
    with urlopen(Request(url, data=body, headers=headers or {}, method=method), timeout=25) as response:
        return response.read()


def post_json(url, body, headers):
    return json.loads(send(url, method="POST", headers={**headers, "Content-Type": "application/json"},
                           body=json.dumps(body).encode()))


def stage_batch(rows, template, *, parent, token):
    headers = {"Authorization": f"Bearer {token}"}
    folder_name = datetime.now(ZoneInfo("Asia/Jakarta")).strftime("%Y-%m-%d_%H%M%S")
    folder = post_json(DRIVE + "?supportsAllDrives=true&fields=id", {
        "name": f"{folder_name}_{uuid4().hex[:8]}",
        "mimeType": "application/vnd.google-apps.folder",
        "parents": [parent],
    }, headers)["id"]

    def upload(row):
        filename = re.sub(r"[^\w]+", "_", f'{row["nama"]}_{row["kelas"]}').strip("_") + ".pdf"
        metadata = {"name": filename, "parents": [folder], "mimeType": "application/pdf"}
        boundary = uuid4().hex
        body = (
            f"--{boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".encode()
            + json.dumps(metadata).encode()
            + f"\r\n--{boundary}\r\nContent-Type: application/pdf\r\n\r\n".encode()
            + pdf_bytes(template, row)
            + f"\r\n--{boundary}--\r\n".encode()
        )
        result = json.loads(send(UPLOAD + "?uploadType=multipart&supportsAllDrives=true&fields=id",
                                 method="POST", body=body, headers={
                                     **headers, "Content-Type": f"multipart/related; boundary={boundary}"
                                 }))
        return {**row, "drive_file_id": result["id"]}

    try:
        with ThreadPoolExecutor(max_workers=4) as workers:
            staged = list(workers.map(upload, rows))
    except Exception:
        trash_folder(folder, headers)
        raise
    return staged


def trash_folder(folder, headers):
    try:
        send(f"{DRIVE}/{folder}?supportsAllDrives=true", method="PATCH",
             headers={**headers, "Content-Type": "application/json"},
             body=b'{"trashed":true}')
    except OSError:
        # The original failure is reported, and the active results remain intact.
        pass


def generate_and_publish(rows, token):
    validate_rows(rows)
    project_url = os.environ["TRYOUT_SUPABASE_URL"].rstrip("/")
    service_key = os.environ["TRYOUT_SUPABASE_SERVICE_KEY"]
    user = json.loads(send(project_url + "/auth/v1/user", headers={
        "apikey": service_key, "Authorization": f"Bearer {token}",
    }))
    if user.get("app_metadata", {}).get("tka_admin") not in (True, "true"):
        raise PermissionError("Akses admin Try Out diperlukan.")

    drive_token = json.loads(send("https://oauth2.googleapis.com/token", method="POST",
                                   headers={"Content-Type": "application/x-www-form-urlencoded"},
                                   body=urlencode({
                                       "grant_type": "refresh_token",
                                       "refresh_token": os.environ["TRYOUT_DRIVE_REFRESH_TOKEN"],
                                       "client_id": os.environ["TRYOUT_DRIVE_CLIENT_ID"],
                                       "client_secret": os.environ["TRYOUT_DRIVE_CLIENT_SECRET"],
                                   }).encode()))["access_token"]
    template_id = os.environ["TRYOUT_DRIVE_TEMPLATE_ID"]
    if not re.fullmatch(r"[A-Za-z0-9_-]{10,200}", template_id):
        raise ValueError("Konfigurasi template PDF tidak valid.")
    template = send(f"{DRIVE}/{template_id}?alt=media&supportsAllDrives=true", headers={
        "Authorization": f"Bearer {drive_token}",
    })
    staged = stage_batch(rows, template, parent=os.environ["TRYOUT_DRIVE_PARENT_ID"], token=drive_token)
    return post_json(project_url + "/rest/v1/rpc/publish_tka_tryout_pdf_batch",
                     {"p_actor": user["id"], "p_rows": staged}, {
                         "apikey": service_key, "Authorization": f"Bearer {service_key}",
                     })


app = Flask(__name__)

def configured():
    return all(os.environ.get(key) for key in ('TRYOUT_SUPABASE_URL', 'TRYOUT_SUPABASE_SERVICE_KEY', 'TRYOUT_DRIVE_CLIENT_ID', 'TRYOUT_DRIVE_CLIENT_SECRET', 'TRYOUT_DRIVE_REFRESH_TOKEN', 'TRYOUT_DRIVE_TEMPLATE_ID', 'TRYOUT_DRIVE_PARENT_ID'))

@app.get("/healthz")
def health():
    return jsonify(service="mumtaza-tryout-pdf", configured=configured())

@app.route('/api/tryout/publish', methods=['POST', 'OPTIONS'])
def publish_tryout_pdf():
    origin = 'https://smpmumtaza.github.io'
    if request.headers.get('Origin') != origin:
        return jsonify(error='Origin tidak diizinkan.'), 403

    def response(body, status):
        result = jsonify(body)
        result.status_code = status
        result.headers.update({
            'Access-Control-Allow-Origin': origin,
            'Access-Control-Allow-Headers': 'Authorization, Content-Type',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Cache-Control': 'no-store',
            'Vary': 'Origin',
        })
        return result

    if request.method == 'OPTIONS':
        return response({}, 204)
    scheme, _, token = request.headers.get('Authorization', '').partition(' ')
    if scheme != 'Bearer' or not token:
        return response({'error': 'Masuk kembali dengan akun admin.'}, 401)
    if request.content_length is None or request.content_length > 4 * 1024 * 1024:
        return response({'error': 'Ukuran data unggahan tidak valid.'}, 413)
    if not configured():
        return response({'error': 'Backend PDF belum dikonfigurasi.'}, 503)
    try:
        body = request.get_json(silent=True)
        return response({'results': generate_and_publish(body, token)}, 200)
    except PermissionError:
        return response({'error': 'Akses admin Try Out diperlukan.'}, 403)
    except ValueError as error:
        return response({'error': str(error)}, 400)
    except OSError:
        app.logger.warning('Try Out PDF publication failed in an upstream service')
        return response({'error': 'Penerbitan belum dapat dikonfirmasi. Periksa hasil aktif sebelum mengulang.'}, 502)
    except KeyError:
        return response({'error': 'Konfigurasi backend PDF belum lengkap.'}, 503)


