#!/usr/bin/env python3
"""
mpris-art-proxy — полный MPRIS2-прокси для mpv.
Регистрируется как org.mpris.MediaPlayer2.mpv_proxy,
реализует оба интерфейса (MediaPlayer2 + Player),
подменяет mpris:artUrl на file:///tmp/cover.png.

Запуск: python3 ~/.config/mpv/mpris-art-proxy.py &
Autostart (hyprland.conf):
  exec-once = python3 ~/.config/mpv/mpris-art-proxy.py

Зависимости:
  sudo pacman -S python-dbus python-gobject
"""

import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import threading
import os
import time
import sys

COVER_PATH = "/tmp/cover.png"
COVER_URI = "file:///tmp/cover.png"
POLL_INTERVAL = 2
STATE_FILE = "/tmp/rofi-media-state"

PROXY_BUS_NAME = "org.mpris.MediaPlayer2.coverart"
MPV_BUS_NAME = "org.mpris.MediaPlayer2.mpv"
MPRIS_PATH = "/org/mpris/MediaPlayer2"

IFACE_ROOT = "org.mpris.MediaPlayer2"
IFACE_PLAYER = "org.mpris.MediaPlayer2.Player"
IFACE_PROPS = "org.freedesktop.DBus.Properties"

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)


def _resolve_mpv_bus_name(bus):
    """Ищем имя mpv на шине по префиксу — mpv может регистрироваться как mpv.instance123."""
    try:
        dbus_obj = bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus")
        iface = dbus.Interface(dbus_obj, "org.freedesktop.DBus")
        names = iface.ListNames()
        for n in names:
            if str(n).startswith(MPV_BUS_NAME):
                return str(n)
    except dbus.exceptions.DBusException:
        pass
    return None


def mpv_props(bus):
    """Интерфейс DBus.Properties реального mpv."""
    try:
        name = _resolve_mpv_bus_name(bus)
        if not name:
            return None
        obj = bus.get_object(name, MPRIS_PATH)
        return dbus.Interface(obj, IFACE_PROPS)
    except dbus.exceptions.DBusException:
        return None


def mpv_player(bus):
    """Интерфейс Player реального mpv."""
    try:
        name = _resolve_mpv_bus_name(bus)
        if not name:
            return None
        obj = bus.get_object(name, MPRIS_PATH)
        return dbus.Interface(obj, IFACE_PLAYER)
    except dbus.exceptions.DBusException:
        return None


def mpv_root(bus):
    """Интерфейс MediaPlayer2 реального mpv."""
    try:
        name = _resolve_mpv_bus_name(bus)
        if not name:
            return None
        obj = bus.get_object(name, MPRIS_PATH)
        return dbus.Interface(obj, IFACE_ROOT)
    except dbus.exceptions.DBusException:
        return None


def patch_metadata(metadata):
    """Заменить artUrl на локальный файл если обложка существует."""
    if not metadata:
        return metadata
    patched = dict(metadata)
    if os.path.exists(COVER_PATH) and os.path.getsize(COVER_PATH) > 0:
        patched["mpris:artUrl"] = dbus.String(COVER_URI)
    return dbus.Dictionary(patched, signature="sv")


class MprisProxy(dbus.service.Object):
    def __init__(self, bus, loop):
        self.bus = bus
        self.loop = loop
        self._last_cover_mtime = 0

        bus_name = dbus.service.BusName(PROXY_BUS_NAME, bus=bus)
        super().__init__(bus_name, MPRIS_PATH)

        t = threading.Thread(target=self._watch_cover, daemon=True)
        t.start()

        # Если mpv уже играет на момент старта прокси — эмитим Playing
        # чтобы swaync показал виджет после рестарта прокси
        GLib.timeout_add(2000, self._on_startup_emit)

    # ── DBus.Properties ──────────────────────────────────────────────────

    @dbus.service.method(IFACE_PROPS, in_signature="ss", out_signature="v")
    def Get(self, interface, prop):
        iface = mpv_props(self.bus)
        if not iface:
            raise dbus.exceptions.DBusException("mpv not running")
        val = iface.Get(interface, prop)
        if interface == IFACE_PLAYER and prop == "Metadata":
            val = patch_metadata(val)
        return val

    @dbus.service.method(IFACE_PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        # print(f"[proxy] GetAll({interface})", flush=True)
        iface = mpv_props(self.bus)
        if not iface:
            if interface == IFACE_ROOT:
                return dbus.Dictionary(
                    {
                        "CanQuit": dbus.Boolean(False),
                        "CanRaise": dbus.Boolean(False),
                        "HasTrackList": dbus.Boolean(False),
                        "Identity": dbus.String("mpv-cover"),
                        "SupportedUriSchemes": dbus.Array([], signature="s"),
                        "SupportedMimeTypes": dbus.Array([], signature="s"),
                    },
                    signature="sv",
                )
            if interface == IFACE_PLAYER:
                # Явно Stopped — swaync с autohide скроет виджет когда mpv не запущен
                return dbus.Dictionary(
                    {
                        "PlaybackStatus": dbus.String("Stopped"),
                        "CanPlay": dbus.Boolean(False),
                        "CanPause": dbus.Boolean(False),
                        "CanSeek": dbus.Boolean(False),
                        "CanControl": dbus.Boolean(False),
                        "CanGoNext": dbus.Boolean(False),
                        "CanGoPrevious": dbus.Boolean(False),
                        "Metadata": dbus.Dictionary({}, signature="sv"),
                    },
                    signature="sv",
                )
            return dbus.Dictionary({}, signature="sv")
        props = dict(iface.GetAll(interface))
        if interface == IFACE_PLAYER and "Metadata" in props:
            props["Metadata"] = patch_metadata(props["Metadata"])
        if interface == IFACE_ROOT and "Identity" in props:
            props["Identity"] = dbus.String("mpv-cover")
        # if interface == IFACE_PLAYER:
        # print(
        #     f"[proxy] GetAll returning PlaybackStatus={props.get('PlaybackStatus', 'MISSING')}",
        #     flush=True,
        # )
        return dbus.Dictionary(props, signature="sv")

    @dbus.service.method(IFACE_PROPS, in_signature="ssv", out_signature="")
    def Set(self, interface, prop, value):
        iface = mpv_props(self.bus)
        if iface:
            iface.Set(interface, prop, value)

    @dbus.service.signal(IFACE_PROPS, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    # ── org.mpris.MediaPlayer2 (root) ─────────────────────────────────────

    @dbus.service.method(IFACE_ROOT, in_signature="", out_signature="")
    def Raise(self):
        r = mpv_root(self.bus)
        if r:
            r.Raise()

    @dbus.service.method(IFACE_ROOT, in_signature="", out_signature="")
    def Quit(self):
        r = mpv_root(self.bus)
        if r:
            r.Quit()

    # ── org.mpris.MediaPlayer2.Player ─────────────────────────────────────

    @dbus.service.method(IFACE_PLAYER, in_signature="", out_signature="")
    def Next(self):
        p = mpv_player(self.bus)
        if p:
            p.Next()

    @dbus.service.method(IFACE_PLAYER, in_signature="", out_signature="")
    def Previous(self):
        p = mpv_player(self.bus)
        if p:
            p.Previous()

    @dbus.service.method(IFACE_PLAYER, in_signature="", out_signature="")
    def Pause(self):
        p = mpv_player(self.bus)
        if p:
            p.Pause()

    @dbus.service.method(IFACE_PLAYER, in_signature="", out_signature="")
    def PlayPause(self):
        p = mpv_player(self.bus)
        if p:
            p.PlayPause()

    @dbus.service.method(IFACE_PLAYER, in_signature="", out_signature="")
    def Stop(self):
        p = mpv_player(self.bus)
        if p:
            p.Stop()

    @dbus.service.method(IFACE_PLAYER, in_signature="", out_signature="")
    def Play(self):
        p = mpv_player(self.bus)
        if p:
            p.Play()

    @dbus.service.method(IFACE_PLAYER, in_signature="x", out_signature="")
    def Seek(self, offset):
        p = mpv_player(self.bus)
        if p:
            p.Seek(offset)

    @dbus.service.method(IFACE_PLAYER, in_signature="ox", out_signature="")
    def SetPosition(self, track_id, position):
        p = mpv_player(self.bus)
        if p:
            p.SetPosition(track_id, position)

    @dbus.service.method(IFACE_PLAYER, in_signature="s", out_signature="")
    def OpenUri(self, uri):
        p = mpv_player(self.bus)
        if p:
            p.OpenUri(uri)

    @dbus.service.signal(IFACE_PLAYER, signature="x")
    def Seeked(self, position):
        pass

    # ── Наблюдатель за обложкой ───────────────────────────────────────────

    def _emit_metadata_changed(self):
        iface = mpv_props(self.bus)
        if not iface:
            return
        try:
            metadata = iface.Get(IFACE_PLAYER, "Metadata")
            patched = patch_metadata(metadata)

            # Шаг 1: эмитим без artUrl — сбрасываем кеш swaync
            cleared = dbus.Dictionary(dict(patched), signature="sv")
            cleared["mpris:artUrl"] = dbus.String("")
            self.PropertiesChanged(
                IFACE_PLAYER,
                dbus.Dictionary({"Metadata": cleared}, signature="sv"),
                dbus.Array([], signature="s"),
            )

            # Шаг 2: эмитим с реальным artUrl через короткую паузу
            def _emit_real():
                try:
                    self.PropertiesChanged(
                        IFACE_PLAYER,
                        dbus.Dictionary({"Metadata": patched}, signature="sv"),
                        dbus.Array([], signature="s"),
                    )
                except Exception:
                    pass

            GLib.timeout_add(300, _emit_real)

        except dbus.exceptions.DBusException:
            pass

    def _emit_stopped(self):
        self.PropertiesChanged(
            IFACE_PLAYER,
            dbus.Dictionary(
                {
                    "PlaybackStatus": dbus.String("Stopped"),
                    "Metadata": dbus.Dictionary({}, signature="sv"),
                },
                signature="sv",
            ),
            dbus.Array([], signature="s"),
        )

    def _on_startup_emit(self):
        """Вызывается один раз при старте — восстанавливает виджет если mpv уже играет."""
        if self._mpv_is_alive():
            self._last_cover_mtime = 0
            self._emit_playing()
        return False  # не повторять

    def _emit_playing(self):
        """Восстанавливаем виджет swaync после возвращения mpv.
        Просто сигналим Playing — обложку подтянет mtime watcher."""
        try:
            self.PropertiesChanged(
                IFACE_PLAYER,
                dbus.Dictionary(
                    {
                        "PlaybackStatus": dbus.String("Playing"),
                    },
                    signature="sv",
                ),
                dbus.Array([], signature="s"),
            )
        except Exception:
            pass

    def _mpv_is_alive(self):
        """Реальная проверка через DBus.ListNames — не обманывается заглушкой get_object.
        Проверяем по префиксу: mpv может регистрироваться как mpv.instance123."""
        try:
            dbus_obj = self.bus.get_object(
                "org.freedesktop.DBus", "/org/freedesktop/DBus"
            )
            iface = dbus.Interface(dbus_obj, "org.freedesktop.DBus")
            names = iface.ListNames()
            return any(str(n).startswith(MPV_BUS_NAME) for n in names)
        except dbus.exceptions.DBusException:
            return False

    def _watch_cover(self):
        mpv_was_alive = False
        while True:
            mpv_alive = self._mpv_is_alive()
            if mpv_was_alive and not mpv_alive:
                # mpv только что исчез — сигналим Stopped и сбрасываем STATE_FILE
                # чтобы следующий rofi-media.sh не считал старую обложку актуальной
                try:
                    os.remove(STATE_FILE)
                except FileNotFoundError:
                    pass
                GLib.idle_add(self._emit_stopped)
            elif not mpv_was_alive and mpv_alive:
                # mpv только что появился — сбрасываем mtime и
                # эмитим Playing чтобы swaync восстановил виджет
                self._last_cover_mtime = 0
                GLib.timeout_add(1000, self._emit_playing)
            mpv_was_alive = mpv_alive

            try:
                mtime = os.path.getmtime(COVER_PATH)
                if mtime != self._last_cover_mtime:
                    self._last_cover_mtime = mtime
                    time.sleep(0.5)
                    GLib.idle_add(self._emit_metadata_changed)
            except (FileNotFoundError, OSError):
                pass
            time.sleep(POLL_INTERVAL)


def main():
    bus = dbus.SessionBus()
    loop = GLib.MainLoop()

    # Пробрасываем PropertiesChanged от реального mpv
    def on_mpv_props_changed(interface, changed, invalidated, sender=None):
        proxy = main._proxy
        if proxy is None:
            return
        if interface == IFACE_PLAYER and "Metadata" in changed:
            changed = dict(changed)
            changed["Metadata"] = patch_metadata(changed["Metadata"])
        try:
            proxy.PropertiesChanged(
                interface,
                dbus.Dictionary(changed, signature="sv"),
                dbus.Array(invalidated, signature="s"),
            )
        except Exception:
            pass

    bus.add_signal_receiver(
        on_mpv_props_changed,
        signal_name="PropertiesChanged",
        dbus_interface=IFACE_PROPS,
        bus_name=MPV_BUS_NAME,
        path=MPRIS_PATH,
        sender_keyword="sender",
    )

    # Пробрасываем Seeked
    def on_mpv_seeked(position, sender=None):
        proxy = main._proxy
        if proxy:
            try:
                proxy.Seeked(position)
            except Exception:
                pass

    bus.add_signal_receiver(
        on_mpv_seeked,
        signal_name="Seeked",
        dbus_interface=IFACE_PLAYER,
        bus_name=MPV_BUS_NAME,
        path=MPRIS_PATH,
        sender_keyword="sender",
    )

    proxy = MprisProxy(bus, loop)
    main._proxy = proxy

    print(f"[mpris-art-proxy] running as {PROXY_BUS_NAME}", flush=True)
    try:
        loop.run()
    except KeyboardInterrupt:
        print("[mpris-art-proxy] stopped")
        sys.exit(0)


main._proxy = None

if __name__ == "__main__":
    main()
