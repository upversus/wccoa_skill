#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
net-test-server — HTTP-сервер для тестирования клиентских функций net*
WinCC OA CTL (netGet, netPost, netPut, netDelete, netHead).

Запуск:
    python tools/net-test-server/net_test_server.py [--port 18080] [--bind 127.0.0.1]

Сервер эмулирует ответы, которые нужны для проверки net* функций:
  GET  /get          -> 200, тело JSON, заголовки X-Probe, Content-Type
  GET  /missing      -> 404, текст
  GET  /error        -> 500, текст
  GET  /bad          -> 400, текст
  GET  /redirect     -> 302 Location: /get   (seguida или нет по followRedirection)
  GET  /hang         -> соединение принимается, ответа нет (проверка блокировки)
  POST /post         -> 201 Created, эхо тела + Content-Type из запроса
  PUT  /put          -> 200 OK, эхо тела
  DELETE /delete     -> 204 No Content
  HEAD /head         -> 200, только заголовки (Content-Length: 0, без тела)
  GET  /target       -> 200, тело (для проверки target-файла)

Ответы логируются в stdout. Каждый запрос получает уникальный id.
"""

import argparse
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from datetime import datetime


class NetTestHandler(BaseHTTPRequestHandler):
    """Обработчик HTTP-запросов для тестирования net*."""

    # Счётчик запросов для уникальных id (потокобезопасно).
    _counter = 0
    _lock = threading.Lock()

    def _next_id(self):
        with self._lock:
            NetTestHandler._counter += 1
            return NetTestHandler._counter

    def log_message(self, format, *args):
        # Переопределяем стандартное логирование: печатаем в UTC с id запроса.
        req_id = self._next_id()
        ts = datetime.utcnow().strftime('%H:%M:%S.%f')[:-3]
        print(f'[{ts}] req={req_id:03d} {self.command} {self.path} -> '
              f'{format % args}', flush=True)

    # ------------------------------------------------------------------
    # Вспомогательные методы
    # ------------------------------------------------------------------
    def _read_body(self):
        length = int(self.headers.get('Content-Length', 0))
        return self.rfile.read(length).decode('utf-8', errors='replace')

    def _send_json(self, code, status_text, payload, extra_headers=None):
        body = json.dumps(payload, ensure_ascii=False).encode('utf-8')
        headers = {
            'Content-Type': 'application/json; charset=utf-8',
            'Content-Length': str(len(body)),
            'X-Probe': 'net-test-server',
        }
        if extra_headers:
            headers.update(extra_headers)
        self.send_response(code, status_text)
        for k, v in headers.items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _send_text(self, code, status_text, text, content_type='text/plain; charset=utf-8'):
        body = text.encode('utf-8')
        headers = {
            'Content-Type': content_type,
            'Content-Length': str(len(body)),
            'X-Probe': 'net-test-server',
        }
        self.send_response(code, status_text)
        for k, v in headers.items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _send_empty(self, code, status_text):
        self.send_response(code, status_text)
        self.send_header('Content-Length', '0')
        self.send_header('X-Probe', 'net-test-server')
        self.end_headers()

    # ------------------------------------------------------------------
    # GET
    # ------------------------------------------------------------------
    def do_GET(self):
        path = self.path.split('?', 1)[0]

        if path == '/get':
            self._send_json(
                200, 'OK',
                {
                    'method': 'GET',
                    'path': '/get',
                    'xProbe': self.headers.get('X-Probe', ''),
                    'serverTime': datetime.utcnow().isoformat() + 'Z',
                },
                extra_headers={'X-Probe': 'get-ok'},
            )
        elif path == '/missing':
            self._send_text(404, 'Not Found', 'nope')
        elif path == '/error':
            self._send_text(500, 'Internal Server Error', 'boom')
        elif path == '/bad':
            self._send_text(400, 'Bad Request', 'bad')
        elif path == '/redirect':
            self.send_response(302, 'Found')
            self.send_header('Location', '/get')
            self.send_header('Content-Length', '0')
            self.send_header('X-Probe', 'redirect-302')
            self.end_headers()
        elif path == '/target':
            body = b'{"target":"ok"}'
            self.send_response(200, 'OK')
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('X-Probe', 'target-ok')
            self.end_headers()
            self.wfile.write(body)
        elif path == '/hang':
            # Соединение принимается, но ответа нет — для проверки
            # блокирующего поведения net* (скрипт повиснет до внешнего таймаута).
            threading.Event().wait()
        else:
            self._send_text(404, 'Not Found', f'unknown path: {path}')

    # ------------------------------------------------------------------
    # POST
    # ------------------------------------------------------------------
    def do_POST(self):
        path = self.path.split('?', 1)[0]
        body = self._read_body()

        if path == '/post':
            self._send_json(
                201, 'Created',
                {
                    'method': 'POST',
                    'path': '/post',
                    'body': body,
                    'contentType': self.headers.get('Content-Type', ''),
                    'xProbe': self.headers.get('X-Probe', ''),
                },
                extra_headers={'X-Probe': 'post-ok'},
            )
        else:
            self._send_text(404, 'Not Found', f'unknown path: {path}')

    # ------------------------------------------------------------------
    # PUT
    # ------------------------------------------------------------------
    def do_PUT(self):
        path = self.path.split('?', 1)[0]
        body = self._read_body()

        if path == '/put':
            self._send_json(
                200, 'OK',
                {
                    'method': 'PUT',
                    'path': '/put',
                    'body': body,
                    'contentType': self.headers.get('Content-Type', ''),
                },
                extra_headers={'X-Probe': 'put-ok'},
            )
        else:
            self._send_text(404, 'Not Found', f'unknown path: {path}')

    # ------------------------------------------------------------------
    # DELETE
    # ------------------------------------------------------------------
    def do_DELETE(self):
        path = self.path.split('?', 1)[0]

        if path == '/delete':
            self._send_empty(204, 'No Content')
        else:
            self._send_text(404, 'Not Found', f'unknown path: {path}')

    # ------------------------------------------------------------------
    # HEAD
    # ------------------------------------------------------------------
    def do_HEAD(self):
        path = self.path.split('?', 1)[0]

        if path == '/head':
            self.send_response(200, 'OK')
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.send_header('Content-Length', '0')
            self.send_header('X-Probe', 'head-ok')
            self.end_headers()
        else:
            self.send_response(404, 'Not Found')
            self.send_header('Content-Length', '0')
            self.end_headers()


def main():
    parser = argparse.ArgumentParser(
        description='HTTP test server for WinCC OA CTL net* functions.'
    )
    parser.add_argument('--port', type=int, default=18080,
                        help='порт сервера (по умолчанию 18080)')
    parser.add_argument('--bind', default='127.0.0.1',
                        help='адрес привязки (по умолчанию 127.0.0.1)')
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.bind, args.port), NetTestHandler)
    print(f'net-test-server listening on {args.bind}:{args.port}', flush=True)
    print('Endpoints:', flush=True)
    print('  GET  /get      -> 200 JSON + headers', flush=True)
    print('  GET  /missing  -> 404 text', flush=True)
    print('  GET  /error    -> 500 text', flush=True)
    print('  GET  /bad      -> 400 text', flush=True)
    print('  GET  /redirect -> 302 to /get', flush=True)
    print('  GET  /target   -> 200 JSON (для target-файла)', flush=True)
    print('  GET  /hang     -> соединение без ответа (блокировка)', flush=True)
    print('  POST /post     -> 201 Created + эхо тела', flush=True)
    print('  PUT  /put      -> 200 OK + эхо тела', flush=True)
    print('  DELETE /delete -> 204 No Content', flush=True)
    print('  HEAD /head     -> 200, только заголовки', flush=True)
    print('Press Ctrl+C to stop.', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nStopping...', flush=True)
        server.shutdown()


if __name__ == '__main__':
    main()
