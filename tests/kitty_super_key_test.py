#!/usr/bin/env python3
"""super キー（Cmd）付きのキーが Neovim にどう届くかを pty で確かめるテスト。

Neovim の TUI は起動時に kitty キーボードプロトコルに対応しているかを
端末へ問い合わせる（CSI ? u と DA1 の CSI c）。このテストは端末の代わりに
その問い合わせへ応答し、super+s と super+shift+z の CSI u シーケンスを送って、
Neovim 側でどのマップが発火するか・どのキー表記として解釈されるかを記録する。

  super+s       -> CSI 115 ; 9 u   （modifiers = super）
  super+shift+z -> CSI 122 ; 10 u  （modifiers = super + shift）

結果を nvim/keymaps.lua のコメント（super+shift+z は <D-Z> として届く）と
突き合わせる。全体は 20 秒で必ず終わり、nvim は子の PID を指定して終了させる。
"""

import errno
import fcntl
import os
import pty
import select
import signal
import struct
import sys
import tempfile
import termios
import time

TIMEOUT_SECONDS = 20

SUPER_S = b"\x1b[115;9u"       # super+s
SUPER_SHIFT_Z = b"\x1b[122;10u"  # super+shift+z

# 端末への問い合わせへの応答
KITTY_QUERY = b"\x1b[?u"
KITTY_REPLY = b"\x1b[?1u"
DA1_QUERY = b"\x1b[c"
DA1_REPLY = b"\x1b[?62;22c"


class Timeout(Exception):
    pass


def _alarm_handler(signum, frame):
    raise Timeout("テストが %d 秒を超えました" % TIMEOUT_SECONDS)


def read_available(fd, received, deadline):
    """fd から読めるだけ読んで received に足す。deadline まで待つ。"""
    while time.time() < deadline:
        timeout = max(0.0, min(0.05, deadline - time.time()))
        try:
            ready, _, _ = select.select([fd], [], [], timeout)
        except (OSError, ValueError):
            return
        if not ready:
            continue
        try:
            data = os.read(fd, 65536)
        except OSError as e:
            if e.errno == errno.EIO:
                return
            raise
        if not data:
            return
        received.extend(data)


def wait_for_queries(fd, received, deadline):
    """kitty プロトコルと DA1 の問い合わせに応答する。"""
    replied_kitty = False
    replied_da1 = False
    while time.time() < deadline:
        if not replied_kitty and KITTY_QUERY in bytes(received):
            os.write(fd, KITTY_REPLY)
            replied_kitty = True
        if not replied_da1 and DA1_QUERY in bytes(received):
            os.write(fd, DA1_REPLY)
            replied_da1 = True
        if replied_kitty and replied_da1:
            return True, True
        read_available(fd, received, min(deadline, time.time() + 0.1))
    return replied_kitty, replied_da1


def drain(fd, received, seconds):
    read_available(fd, received, time.time() + seconds)


def child_exited(pid):
    try:
        wpid, _status = os.waitpid(pid, os.WNOHANG)
    except ChildProcessError:
        return True
    return wpid == pid


def terminate(pid, fd):
    """nvim を終了させる。まず :q! を送り、だめなら子の PID にシグナルを送る。"""
    try:
        os.write(fd, b"\x1b:q!\r")
    except OSError:
        pass

    deadline = time.time() + 1.5
    while time.time() < deadline:
        if child_exited(pid):
            return
        time.sleep(0.02)

    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.kill(pid, sig)
        except ProcessLookupError:
            return
        deadline = time.time() + 1.0
        while time.time() < deadline:
            if child_exited(pid):
                return
            time.sleep(0.02)


def lua_string(value):
    """Lua のシングルクォート文字列にする（パス用）。"""
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def build_nvim_args(result_path):
    path = lua_string(result_path)

    def write_call(line):
        return "vim.fn.writefile({%s}, %s, 'a')" % (lua_string(line), path)

    def write_fired(key, name):
        return "lua vim.keymap.set('n', %s, function() %s end)" % (
            lua_string(key),
            write_call("fired=" + name),
        )

    # nvim が受け取ったキー（マップ適用前）を <D-s> などの表記で記録する
    logger = (
        "lua vim.on_key(function(_, typed) "
        "if #typed > 1 then "
        "local ok, s = pcall(vim.fn.keytrans, typed) "
        "if ok then vim.fn.writefile({'typed=' .. s}, %s, 'a') end "
        "end end)" % path
    )

    return [
        "nvim",
        "--clean",
        "-u",
        "NONE",
        "-i",
        "NONE",
        "-n",
        "--cmd",
        logger,
        "--cmd",
        write_fired("<D-s>", "super+s"),
        "--cmd",
        write_fired("<D-Z>", "super+shift+z"),
        # <D-Z> と <D-S-z> が Neovim で同じキーになることを記録する
        "-c",
        "lua local z = vim.fn.maparg('<D-Z>', 'n') "
        "local sz = vim.fn.maparg('<D-S-z>', 'n') "
        "vim.fn.writefile({'map-D-Z=' .. z, 'map-D-S-z=' .. sz, "
        "'alias=' .. tostring(z ~= '' and z == sz)}, %s, 'a')" % path,
    ]


def run():
    # 結果ファイル・nvim の作業ディレクトリは一時ディレクトリに置き、
    # 終了時にまとめて片付ける（リポジトリや実ファイルを汚さない）。
    with tempfile.TemporaryDirectory(prefix="kitty-super-key-test-") as tmpdir:
        result_path = os.path.join(tmpdir, "result.txt")
        open(result_path, "w").close()

        args = build_nvim_args(result_path)

        pid, fd = pty.fork()
        if pid == 0:  # 子プロセス
            try:
                os.chdir(tmpdir)
                os.environ["TERM"] = "xterm-256color"
                os.execvpe(args[0], args, os.environ)
            finally:
                os._exit(127)

        # 画面サイズを与えないと nvim が 0x0 で起動してしまう
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))

        received = bytearray()
        try:
            replied_kitty, replied_da1 = wait_for_queries(fd, received, time.time() + 10)
            if not (replied_kitty and replied_da1):
                print("端末問い合わせへの応答に失敗しました: kitty=%s DA1=%s" % (replied_kitty, replied_da1))
                return 1

            # TUI が描画され、--cmd のマップが有効になるのを待つ
            drain(fd, received, 0.5)
            if b"NVIM" not in bytes(received):
                print("Neovim の TUI が起動したことを確認できませんでした")
                return 1

            os.write(fd, SUPER_S)
            drain(fd, received, 0.5)
            os.write(fd, SUPER_SHIFT_Z)
            drain(fd, received, 0.5)
        finally:
            terminate(pid, fd)
            try:
                os.close(fd)
            except OSError:
                pass

        with open(result_path, "r", encoding="utf-8", errors="replace") as f:
            lines = [line.rstrip("\n") for line in f if line.strip()]

        print("nvim が記録した内容:")
        for line in lines:
            print("  " + line)

        fired = {line[len("fired="):] for line in lines if line.startswith("fired=")}
        typed = [line[len("typed="):] for line in lines if line.startswith("typed=")]
        alias = "alias=true" in lines

        ok = True

        if "super+s" in fired:
            print("OK: super+s -> <D-s> のマップが発火")
        else:
            print("NG: super+s のマップが発火しなかった")
            ok = False

        if "super+shift+z" in fired:
            print("OK: super+shift+z -> <D-Z>/<D-S-z> のマップが発火")
        else:
            print("NG: super+shift+z のマップが発火しなかった")
            ok = False

        if not alias:
            print("NG: <D-Z> と <D-S-z> が同じキーになっていない")
            ok = False

        # Neovim のキー表記（マップ適用前）を確認する。
        # keymaps.lua は「super+shift+z は <D-Z> として届く」と書いているので、
        # ここが変わったら keymaps.lua のコメントと定義を見直す。
        print("super+s のキー表記: " + (typed[0] if len(typed) > 0 else "(記録なし)"))
        shift_z_notation = typed[1] if len(typed) > 1 else "(記録なし)"
        print("super+shift+z のキー表記: " + shift_z_notation)

        if typed[:2] != ["<D-s>", "<D-Z>"]:
            print("NG: キー表記が想定（<D-s>, <D-Z>）と違う。keymaps.lua の定義とコメントを見直すこと")
            ok = False

        if ok:
            print("すべての確認が成功しました")

        return 0 if ok else 1


def main():
    signal.signal(signal.SIGALRM, _alarm_handler)
    signal.alarm(TIMEOUT_SECONDS)
    try:
        return run()
    except Timeout as e:
        print("NG: " + str(e))
        return 1
    finally:
        signal.alarm(0)


if __name__ == "__main__":
    sys.exit(main())
