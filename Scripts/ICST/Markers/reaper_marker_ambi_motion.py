#!/usr/bin/env python3
"""
Send ICST AmbiEncoder movements from REAPER marker pairs.

Workflow:
  1. Enable REAPER Web browser control, usually on port 8080.
  2. Create a time selection between two project markers.
  3. Name the markers with Ambi target positions, for example:
       ambi 1 a=-45 e=0 d=0.8
       ambi 1 a=45 e=20 d=0.8
  4. Run this script. The time selection length becomes the movement duration.

The script sends:
  /icst/ambi/sourceindex/aed <index> <azimuth> <elevation> <distance>
or, for named sources:
  /icst/ambi/source/aed <name> <azimuth> <elevation> <distance>
"""

from __future__ import annotations

import argparse
import math
import os
import shlex
import sys
import tempfile
import threading
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


SCRIPT_NAME = "REAPER Marker Ambi Motion"
WORKER_VERSION = "5"


@dataclass
class ReaperMarker:
    index: int
    position: float
    name: str


@dataclass
class ReaperSnapshot:
    selection_start: float
    selection_end: float
    markers: list[ReaperMarker]
    motion_start: Optional[float] = None
    motion_end: Optional[float] = None


@dataclass
class AmbiPoint:
    source: str
    azimuth: float
    elevation: float
    distance: float


def lua_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build_snapshot_lua(output_path: Path) -> str:
    quoted_output_path = lua_quote(str(output_path))
    return f"""
local output_path = {quoted_output_path}
local file = io.open(output_path, "w")
if not file then return end

local ts_start, ts_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
file:write(string.format("selection\\t%.17g\\t%.17g\\n", ts_start, ts_end))

local _, marker_count, region_count = reaper.CountProjectMarkers(0)
local total_count = marker_count + region_count
for i = 0, total_count - 1 do
  local ok, is_region, pos, _, name, index = reaper.EnumProjectMarkers3(0, i)
  if ok and not is_region then
    name = (name or ""):gsub("\\r", " "):gsub("\\n", " "):gsub("\\t", " ")
    file:write(string.format("marker\\t%.17g\\t%d\\t%s\\n", pos, index, name))
  end
end

file:close()
"""


class ReaperWebClient:
    def __init__(self, host: str, port: int, scripts_dir: Path) -> None:
        self.host = host
        self.port = port
        self.scripts_dir = scripts_dir.expanduser()
        self.scripts_dir.mkdir(parents=True, exist_ok=True)
        self.script_path = self.scripts_dir / "_marker_ambi_motion_snapshot.lua"
        self.output_path = Path(tempfile.gettempdir()) / "_marker_ambi_motion_snapshot.tsv"

    @property
    def base_url(self) -> str:
        return f"http://{self.host}:{self.port}"

    def execute_lua(self, lua_code: str) -> None:
        self.script_path.write_text(lua_code, encoding="utf-8")
        encoded_path = urllib.parse.quote(str(self.script_path), safe="/")
        url = f"{self.base_url}/_/2/{encoded_path}"
        with urllib.request.urlopen(url, timeout=5) as response:
            response.read()

    def read_snapshot(self) -> ReaperSnapshot:
        if self.output_path.exists():
            self.output_path.unlink()
        self.execute_lua(build_snapshot_lua(self.output_path))

        deadline = time.monotonic() + 2.0
        while not self.output_path.exists() and time.monotonic() < deadline:
            time.sleep(0.05)

        if not self.output_path.exists():
            raise RuntimeError(
                "REAPER hat keine Snapshot-Datei geschrieben. "
                "Bitte pruefen: Web browser control aktiv, Port korrekt, "
                "und REAPER darf ReaScript-Dateien ausfuehren."
            )

        rows = self.output_path.read_text(encoding="utf-8").splitlines()
        selection_start: Optional[float] = None
        selection_end: Optional[float] = None
        markers: list[ReaperMarker] = []
        motion_start: Optional[float] = None
        motion_end: Optional[float] = None

        for row in rows:
            parts = row.split("\t", 3)
            if not parts:
                continue
            if parts[0] == "selection" and len(parts) >= 3:
                selection_start = float(parts[1])
                selection_end = float(parts[2])
            elif parts[0] == "motion" and len(parts) >= 3:
                motion_start = float(parts[1])
                motion_end = float(parts[2])
            elif parts[0] == "marker" and len(parts) == 4:
                markers.append(
                    ReaperMarker(
                        position=float(parts[1]),
                        index=int(parts[2]),
                        name=parts[3],
                    )
                )

        if selection_start is None or selection_end is None:
            raise RuntimeError("Konnte REAPER Time Selection nicht lesen.")

        markers.sort(key=lambda marker: marker.position)
        return ReaperSnapshot(selection_start, selection_end, markers, motion_start, motion_end)


def read_snapshot_file(snapshot_file: Path) -> ReaperSnapshot:
    rows = snapshot_file.expanduser().read_text(encoding="utf-8").splitlines()
    selection_start: Optional[float] = None
    selection_end: Optional[float] = None
    markers: list[ReaperMarker] = []
    motion_start: Optional[float] = None
    motion_end: Optional[float] = None

    for row in rows:
        parts = row.split("\t", 3)
        if not parts:
            continue
        if parts[0] == "selection" and len(parts) >= 3:
            selection_start = float(parts[1])
            selection_end = float(parts[2])
        elif parts[0] == "motion" and len(parts) >= 3:
            motion_start = float(parts[1])
            motion_end = float(parts[2])
        elif parts[0] == "marker" and len(parts) == 4:
            markers.append(
                ReaperMarker(
                    position=float(parts[1]),
                    index=int(parts[2]),
                    name=parts[3],
                )
            )

    if selection_start is None or selection_end is None:
        raise RuntimeError(f"Konnte Snapshot-Datei nicht lesen: {snapshot_file}")

    markers.sort(key=lambda marker: marker.position)
    return ReaperSnapshot(selection_start, selection_end, markers, motion_start, motion_end)


def normalize_key(key: str) -> str:
    key = key.lower().strip("-_")
    aliases = {
        "a": "azimuth",
        "az": "azimuth",
        "azi": "azimuth",
        "e": "elevation",
        "el": "elevation",
        "ele": "elevation",
        "d": "distance",
        "dist": "distance",
        "r": "distance",
        "src": "source",
        "s": "source",
    }
    return aliases.get(key, key)


def parse_marker_name(name: str) -> Optional[AmbiPoint]:
    cleaned = name.replace(":", " ")
    try:
        tokens = shlex.split(cleaned)
    except ValueError:
        tokens = cleaned.split()

    if not tokens or tokens[0].lower() != "ambi":
        return None

    source: Optional[str] = None
    values: dict[str, float] = {}

    for token in tokens[1:]:
        if "=" in token:
            raw_key, raw_value = token.split("=", 1)
            key = normalize_key(raw_key)
            if key == "source":
                source = raw_value
            elif key in {"azimuth", "elevation", "distance"}:
                values[key] = float(raw_value)
        elif source is None:
            source = token

    if source is None:
        source = "1"

    missing = {"azimuth", "elevation", "distance"} - set(values)
    if missing:
        raise ValueError(f"Marker '{name}' hat fehlende Werte: {', '.join(sorted(missing))}")

    return AmbiPoint(
        source=source,
        azimuth=values["azimuth"],
        elevation=values["elevation"],
        distance=values["distance"],
    )


def nearest_ambi_marker(markers: list[ReaperMarker], position: float, tolerance: float) -> tuple[ReaperMarker, AmbiPoint]:
    candidates: list[tuple[float, ReaperMarker, AmbiPoint]] = []
    for marker in markers:
        distance = abs(marker.position - position)
        if distance > tolerance:
            continue
        point = parse_marker_name(marker.name)
        if point is not None:
            candidates.append((distance, marker, point))

    if not candidates:
        raise RuntimeError(
            f"Kein Ambi-Marker innerhalb von {tolerance:.3f}s bei {position:.3f}s gefunden."
        )

    _, marker, point = min(candidates, key=lambda item: item[0])
    return marker, point


def ambi_points_near_position(markers: list[ReaperMarker], position: float, tolerance: float) -> dict[str, tuple[ReaperMarker, AmbiPoint]]:
    candidates: dict[str, tuple[float, ReaperMarker, AmbiPoint]] = {}

    for marker in markers:
        distance = abs(marker.position - position)
        if distance > tolerance:
            continue
        point = parse_marker_name(marker.name)
        if point is None:
            continue

        current = candidates.get(point.source)
        if current is None or distance < current[0]:
            candidates[point.source] = (distance, marker, point)

    return {
        source: (marker, point)
        for source, (_, marker, point) in candidates.items()
    }


def polyphonic_pairs(
    markers: list[ReaperMarker],
    start_position: float,
    end_position: float,
    tolerance: float,
) -> list[tuple[ReaperMarker, AmbiPoint, ReaperMarker, AmbiPoint]]:
    start_points = ambi_points_near_position(markers, start_position, tolerance)
    end_points = ambi_points_near_position(markers, end_position, tolerance)
    common_sources = sorted(start_points.keys() & end_points.keys(), key=lambda source: (not source.isdigit(), int(source) if source.isdigit() else source))

    if not common_sources:
        raise RuntimeError(
            f"Keine passenden polyphonen Ambi-Quellen bei {start_position:.3f}s und {end_position:.3f}s gefunden."
        )

    return [
        (start_points[source][0], start_points[source][1], end_points[source][0], end_points[source][1])
        for source in common_sources
    ]


@dataclass
class SeriesSegment:
    start_position: float
    end_position: float
    pairs: list[tuple[ReaperMarker, AmbiPoint, ReaperMarker, AmbiPoint]]

    @property
    def duration(self) -> float:
        return abs(self.end_position - self.start_position)


def cue_positions_between(
    markers: list[ReaperMarker],
    start_position: float,
    end_position: float,
    tolerance: float,
) -> list[float]:
    low = min(start_position, end_position) - tolerance
    high = max(start_position, end_position) + tolerance
    positions = sorted({marker.position for marker in markers if low <= marker.position <= high})
    if start_position > end_position:
        positions.reverse()
    return positions


def build_series_segments(
    markers: list[ReaperMarker],
    start_position: float,
    end_position: float,
    tolerance: float,
) -> list[SeriesSegment]:
    positions = cue_positions_between(markers, start_position, end_position, tolerance)
    if len(positions) < 2:
        raise RuntimeError("Fuer eine Serie werden mindestens zwei Ambi-Cue-Zeitpunkte benoetigt.")

    segments: list[SeriesSegment] = []
    for segment_start, segment_end in zip(positions, positions[1:]):
        if abs(segment_end - segment_start) <= 0.000001:
            continue
        pairs = polyphonic_pairs(markers, segment_start, segment_end, tolerance)
        segments.append(SeriesSegment(segment_start, segment_end, pairs))

    if not segments:
        raise RuntimeError("Keine gueltigen seriellen Ambi-Segmente gefunden.")
    return segments


def shortest_angle_delta(start: float, end: float) -> float:
    return (end - start + 180.0) % 360.0 - 180.0


def interpolate(start: float, end: float, progress: float, is_angle: bool = False) -> float:
    if is_angle:
        return start + shortest_angle_delta(start, end) * progress
    return start + (end - start) * progress


def smoothstep(progress: float) -> float:
    progress = max(0.0, min(1.0, progress))
    return progress * progress * (3.0 - 2.0 * progress)


def parabolic(progress: float) -> float:
    progress = max(0.0, min(1.0, progress))
    if progress < 0.5:
        return 2.0 * progress * progress
    return 1.0 - ((-2.0 * progress + 2.0) ** 2.0) / 2.0


def exponential(progress: float) -> float:
    progress = max(0.0, min(1.0, progress))
    if progress <= 0.0 or progress >= 1.0:
        return progress
    if progress < 0.5:
        return (2.0 ** (20.0 * progress - 10.0)) / 2.0
    return (2.0 - (2.0 ** (-20.0 * progress + 10.0))) / 2.0


def curve_progress(progress: float, curve: str) -> float:
    if curve == "smoothstep":
        return smoothstep(progress)
    if curve == "parabolic":
        return parabolic(progress)
    if curve == "exponential":
        return exponential(progress)
    return max(0.0, min(1.0, progress))


def aed_to_xyz(point: AmbiPoint) -> tuple[float, float, float]:
    azimuth = math.radians(point.azimuth)
    elevation = math.radians(point.elevation)
    radius = point.distance
    horizontal = radius * math.cos(elevation)
    x = horizontal * math.sin(azimuth)
    y = horizontal * math.cos(azimuth)
    z = radius * math.sin(elevation)
    return x, y, z


def xyz_to_aed(source: str, x: float, y: float, z: float) -> AmbiPoint:
    distance = math.sqrt((x * x) + (y * y) + (z * z))
    if distance <= 0.000001:
        return AmbiPoint(source=source, azimuth=0.0, elevation=0.0, distance=0.0)
    azimuth = math.degrees(math.atan2(x, y))
    elevation = math.degrees(math.asin(max(-1.0, min(1.0, z / distance))))
    return AmbiPoint(source=source, azimuth=azimuth, elevation=elevation, distance=distance)


def interpolate_xyz(start: AmbiPoint, end: AmbiPoint, progress: float) -> AmbiPoint:
    start_xyz = aed_to_xyz(start)
    end_xyz = aed_to_xyz(end)
    x = interpolate(start_xyz[0], end_xyz[0], progress)
    y = interpolate(start_xyz[1], end_xyz[1], progress)
    z = interpolate(start_xyz[2], end_xyz[2], progress)
    return xyz_to_aed(start.source, x, y, z)


def interpolate_polar(start: AmbiPoint, end: AmbiPoint, progress: float) -> AmbiPoint:
    return AmbiPoint(
        source=start.source,
        azimuth=interpolate(start.azimuth, end.azimuth, progress, is_angle=True),
        elevation=interpolate(start.elevation, end.elevation, progress),
        distance=interpolate(start.distance, end.distance, progress),
    )


def interpolate_aed(start: AmbiPoint, end: AmbiPoint, progress: float, curve: str) -> AmbiPoint:
    if curve == "linear":
        return interpolate_xyz(start, end, progress)
    if curve == "polar":
        return interpolate_polar(start, end, progress)
    return AmbiPoint(
        source=start.source,
        azimuth=interpolate(start.azimuth, end.azimuth, progress, is_angle=True),
        elevation=interpolate(start.elevation, end.elevation, progress),
        distance=interpolate(start.distance, end.distance, progress),
    )


def send_motion(
    client: object,
    start: AmbiPoint,
    end: AmbiPoint,
    duration: float,
    steps_per_second: float,
    curve: str,
    stop_event: Optional[threading.Event] = None,
) -> None:
    if start.source != end.source:
        raise RuntimeError(f"Start/Ende verwenden unterschiedliche Quellen: {start.source} vs {end.source}")

    source_as_index: Optional[int]
    try:
        source_as_index = int(start.source)
    except ValueError:
        source_as_index = None

    address = "/icst/ambi/sourceindex/aed" if source_as_index is not None else "/icst/ambi/source/aed"
    source_arg: object = source_as_index if source_as_index is not None else start.source
    step_count = max(1, int(math.ceil(duration * steps_per_second)))
    start_time = time.monotonic()

    for step in range(step_count + 1):
        if stop_event is not None and stop_event.is_set():
            return

        raw_progress = step / step_count
        progress = curve_progress(raw_progress, curve)
        point = interpolate_aed(start, end, progress, curve)

        client.send_message(address, [source_arg, point.azimuth, point.elevation, point.distance])

        next_time = start_time + (duration * (step + 1) / step_count)
        sleep_time = next_time - time.monotonic()
        if step < step_count and sleep_time > 0:
            if stop_event is not None:
                if stop_event.wait(sleep_time):
                    return
            else:
                time.sleep(sleep_time)


def source_address_and_arg(source: str) -> tuple[str, object]:
    try:
        source_as_index = int(source)
    except ValueError:
        return "/icst/ambi/source/aed", source
    return "/icst/ambi/sourceindex/aed", source_as_index


def send_polyphonic_motion(
    client: object,
    pairs: list[tuple[ReaperMarker, AmbiPoint, ReaperMarker, AmbiPoint]],
    duration: float,
    steps_per_second: float,
    curve: str,
    stop_event: Optional[threading.Event] = None,
) -> None:
    step_count = max(1, int(math.ceil(duration * steps_per_second)))
    start_time = time.monotonic()

    for step in range(step_count + 1):
        if stop_event is not None and stop_event.is_set():
            return

        raw_progress = step / step_count
        progress = curve_progress(raw_progress, curve)

        for _, start_point, _, end_point in pairs:
            if stop_event is not None and stop_event.is_set():
                return
            if start_point.source != end_point.source:
                continue
            address, source_arg = source_address_and_arg(start_point.source)
            point = interpolate_aed(start_point, end_point, progress, curve)
            client.send_message(address, [source_arg, point.azimuth, point.elevation, point.distance])

        next_time = start_time + (duration * (step + 1) / step_count)
        sleep_time = next_time - time.monotonic()
        if step < step_count and sleep_time > 0:
            if stop_event is not None:
                if stop_event.wait(sleep_time):
                    return
            else:
                time.sleep(sleep_time)


def send_series_motion(
    client: object,
    segments: list[SeriesSegment],
    steps_per_second: float,
    curve: str,
    stop_event: Optional[threading.Event] = None,
    segment_callback: Optional[object] = None,
) -> None:
    for index, segment in enumerate(segments, start=1):
        if stop_event is not None and stop_event.is_set():
            return
        if segment_callback is not None:
            segment_callback(index, len(segments), segment)
        send_polyphonic_motion(
            client,
            segment.pairs,
            segment.duration,
            steps_per_second,
            curve,
            stop_event,
        )


@dataclass
class WorkerRequest:
    job_id: str
    snapshot_file: Path
    ambi_host: str
    ambi_port: int
    steps_per_second: float
    curve: str
    marker_tolerance: float
    polyphonic: bool
    start_delay: float
    series: bool


class NullOSCClient:
    def send_message(self, address: str, values: list[object]) -> None:
        return


def atomic_write_text(path: Path, text: str) -> None:
    temporary_path = path.with_suffix(path.suffix + ".tmp")
    temporary_path.write_text(text, encoding="utf-8")
    temporary_path.replace(path)


def read_key_value_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or "\t" not in line:
            continue
        key, value = line.split("\t", 1)
        values[key] = value
    return values


def remove_generated_snapshot(path: Path) -> None:
    try:
        resolved = path.expanduser().resolve()
        allowed_temp_roots = {
            Path(tempfile.gettempdir()).resolve(),
            Path("/tmp").resolve(),
        }
        if resolved.parent in allowed_temp_roots and resolved.name.startswith("_marker_ambi_motion_snapshot_"):
            resolved.unlink(missing_ok=True)
    except OSError:
        pass


def pid_is_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except (OSError, ProcessLookupError):
        return False
    return True


class MotionWorker:
    def __init__(self, command_dir: Path) -> None:
        self.command_dir = command_dir.expanduser()
        self.command_dir.mkdir(parents=True, exist_ok=True)
        self.command_path = self.command_dir / "command.tsv"
        self.status_path = self.command_dir / "status.tsv"
        self.pid_path = self.command_dir / "worker.pid"
        self.last_job_id = ""
        self.motion_thread: Optional[threading.Thread] = None
        self.stop_event: Optional[threading.Event] = None
        self.shutdown_requested = False
        self.status_lock = threading.Lock()
        self.status: dict[str, str] = {
            "state": "starting",
            "job_id": "",
            "message": "Worker startet.",
            "sources": "",
            "version": WORKER_VERSION,
        }

    def acquire_pid_lock(self) -> None:
        if self.pid_path.exists():
            try:
                existing_pid = int(self.pid_path.read_text(encoding="utf-8").strip())
            except (OSError, ValueError):
                existing_pid = 0
            if existing_pid > 0 and pid_is_running(existing_pid):
                raise RuntimeError(f"Worker laeuft bereits mit PID {existing_pid}.")
            self.pid_path.unlink(missing_ok=True)

        atomic_write_text(self.pid_path, str(os.getpid()))

    def release_pid_lock(self) -> None:
        try:
            if self.pid_path.exists() and self.pid_path.read_text(encoding="utf-8").strip() == str(os.getpid()):
                self.pid_path.unlink()
        except OSError:
            pass

    def update_status(self, **values: object) -> None:
        with self.status_lock:
            for key, value in values.items():
                self.status[key] = str(value).replace("\t", " ").replace("\r", " ").replace("\n", " ")
            self.status["pid"] = str(os.getpid())
            self.status["version"] = WORKER_VERSION
            self.status["heartbeat"] = f"{time.time():.6f}"
            lines = [f"{key}\t{value}" for key, value in sorted(self.status.items())]
            atomic_write_text(self.status_path, "\n".join(lines) + "\n")

    def cancel_current_job(self, message: str = "Bewegung gestoppt.", job_id: Optional[str] = None) -> None:
        had_active_job = self.stop_event is not None or (
            self.motion_thread is not None and self.motion_thread.is_alive()
        )
        if self.stop_event is not None:
            self.stop_event.set()
        if self.motion_thread is not None and self.motion_thread.is_alive():
            self.motion_thread.join(timeout=1.0)
        self.motion_thread = None
        self.stop_event = None
        if not had_active_job and job_id is None:
            return
        status_values: dict[str, object] = {
            "state": "stopped",
            "message": message,
            "sources": "",
            "segment": "",
        }
        if job_id is not None:
            status_values["job_id"] = job_id
        self.update_status(**status_values)

    def parse_request(self, values: dict[str, str]) -> WorkerRequest:
        return WorkerRequest(
            job_id=values["job_id"],
            snapshot_file=Path(values["snapshot_file"]),
            ambi_host=(values.get("ambi_host") or "").strip() or "127.0.0.1",
            ambi_port=int((values.get("ambi_port") or "").strip() or "50001"),
            steps_per_second=float(values.get("steps_per_second", "40")),
            curve=values.get("curve", "smoothstep"),
            marker_tolerance=float(values.get("marker_tolerance", "0.25")),
            polyphonic=values.get("polyphonic", "0") in {"1", "true", "yes", "on"},
            start_delay=max(0.0, float(values.get("start_delay", "0.05"))),
            series=values.get("series", "0") in {"1", "true", "yes", "on"},
        )

    def run_request(self, request: WorkerRequest, stop_event: threading.Event) -> None:
        try:
            if os.environ.get("REAPER_AMBI_DRY_RUN") == "1":
                client: object = NullOSCClient()
            else:
                from pythonosc.udp_client import SimpleUDPClient

                client = SimpleUDPClient(request.ambi_host, request.ambi_port)

            snapshot = read_snapshot_file(request.snapshot_file)
            remove_generated_snapshot(request.snapshot_file)
            duration = snapshot.selection_end - snapshot.selection_start
            if duration <= 0:
                raise RuntimeError("Snapshot enthaelt keine gueltige Dauer.")

            motion_start = snapshot.motion_start if snapshot.motion_start is not None else snapshot.selection_start
            motion_end = snapshot.motion_end if snapshot.motion_end is not None else snapshot.selection_end
            if request.start_delay > 0 and stop_event.wait(request.start_delay):
                return

            if request.series:
                segments = build_series_segments(
                    snapshot.markers,
                    motion_start,
                    motion_end,
                    request.marker_tolerance,
                )
                all_sources = sorted(
                    {
                        pair[1].source
                        for segment in segments
                        for pair in segment.pairs
                    },
                    key=lambda source: (not source.isdigit(), int(source) if source.isdigit() else source),
                )

                def update_segment_status(index: int, total: int, segment: SeriesSegment) -> None:
                    self.update_status(
                        state="running",
                        job_id=request.job_id,
                        message=(
                            f"Serie Segment {index}/{total}: "
                            f"{segment.start_position:.3f}s -> {segment.end_position:.3f}s"
                        ),
                        sources=", ".join(all_sources),
                        segment=f"{index}/{total}",
                    )

                send_series_motion(
                    client,
                    segments,
                    request.steps_per_second,
                    request.curve,
                    stop_event,
                    update_segment_status,
                )
            elif request.polyphonic:
                pairs = polyphonic_pairs(snapshot.markers, motion_start, motion_end, request.marker_tolerance)
                sources = ", ".join(pair[1].source for pair in pairs)
                self.update_status(
                    state="running",
                    job_id=request.job_id,
                    message=f"Polyphone Bewegung laeuft: {duration:.3f}s",
                    sources=sources,
                    segment="",
                )
                send_polyphonic_motion(
                    client,
                    pairs,
                    duration,
                    request.steps_per_second,
                    request.curve,
                    stop_event,
                )
            else:
                _, start_point = nearest_ambi_marker(snapshot.markers, motion_start, request.marker_tolerance)
                _, end_point = nearest_ambi_marker(snapshot.markers, motion_end, request.marker_tolerance)
                self.update_status(
                    state="running",
                    job_id=request.job_id,
                    message=f"Bewegung laeuft: {duration:.3f}s",
                    sources=start_point.source,
                    segment="",
                )
                send_motion(
                    client,
                    start_point,
                    end_point,
                    duration,
                    request.steps_per_second,
                    request.curve,
                    stop_event,
                )

            if stop_event.is_set():
                self.update_status(
                    state="stopped",
                    job_id=request.job_id,
                    message="Bewegung gestoppt.",
                    sources="",
                    segment="",
                )
            else:
                self.update_status(
                    state="completed",
                    job_id=request.job_id,
                    message="Serie beendet." if request.series else "Bewegung beendet.",
                    sources="",
                    segment="",
                )
        except Exception as exc:
            self.update_status(
                state="error",
                job_id=request.job_id,
                message=str(exc),
                sources="",
            )

    def start_request(self, request: WorkerRequest) -> None:
        self.cancel_current_job("Vorherige Bewegung ersetzt.")
        stop_event = threading.Event()
        self.stop_event = stop_event
        self.motion_thread = threading.Thread(
            target=self.run_request,
            args=(request, stop_event),
            name=f"ambi-motion-{request.job_id}",
            daemon=True,
        )
        self.motion_thread.start()

    def handle_command(self, values: dict[str, str]) -> None:
        job_id = values.get("job_id", "")
        if not job_id or job_id == self.last_job_id:
            return
        self.last_job_id = job_id
        command = values.get("command", "")

        if command == "start":
            self.start_request(self.parse_request(values))
        elif command == "stop":
            self.cancel_current_job(job_id=job_id)
        elif command == "shutdown":
            self.cancel_current_job("Worker wird beendet.", job_id=job_id)
            self.shutdown_requested = True
        elif command == "clear":
            if self.motion_thread is None or not self.motion_thread.is_alive():
                self.update_status(state="idle", job_id=job_id, message="Worker bereit.", sources="")
        else:
            self.update_status(state="error", job_id=job_id, message=f"Unbekanntes Kommando: {command}")

    def serve(self) -> int:
        self.acquire_pid_lock()
        self.update_status(state="idle", message="Worker bereit.", sources="")
        last_heartbeat = time.monotonic()

        try:
            while not self.shutdown_requested:
                if self.command_path.exists():
                    try:
                        self.handle_command(read_key_value_file(self.command_path))
                    except Exception as exc:
                        self.update_status(state="error", message=f"Command-Fehler: {exc}", sources="")
                now = time.monotonic()
                if now - last_heartbeat >= 0.25:
                    self.update_status()
                    last_heartbeat = now
                time.sleep(0.02)
            return 0
        finally:
            if self.stop_event is not None:
                self.stop_event.set()
            self.release_pid_lock()


def run_worker(command_dir: Path) -> int:
    worker = MotionWorker(command_dir)
    try:
        return worker.serve()
    except Exception as exc:
        print(f"Worker-Fehler: {exc}", file=sys.stderr)
        return 1


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Sendet Marker-basierte AmbiEncoder-Bewegungen aus REAPER.")
    parser.add_argument("--ambi-host", default="127.0.0.1", help="Zielhost des ICST AmbiEncoder OSC In")
    parser.add_argument("--ambi-port", type=int, default=50001, help="Zielport des ICST AmbiEncoder OSC In")
    parser.add_argument("--reaper-host", default="127.0.0.1", help="REAPER Web Host")
    parser.add_argument("--reaper-port", type=int, default=8080, help="REAPER Web Port")
    parser.add_argument("--snapshot-file", type=Path, help="Von einer REAPER-Lua-Action geschriebene Snapshot-Datei")
    parser.add_argument("--worker", action="store_true", help="Als persistenter Motion-Worker laufen")
    parser.add_argument(
        "--command-dir",
        type=Path,
        default=Path(tempfile.gettempdir()) / "reaper_ambi_motion_worker",
        help="Verzeichnis fuer Worker-Kommandos und Status",
    )
    parser.add_argument("--polyphonic", action="store_true", help="Alle passenden ambi <source>-Marker pro Start/Ende senden")
    parser.add_argument("--series", action="store_true", help="Alle Ambi-Cues zwischen Start und Ende seriell abfahren")
    parser.add_argument("--marker-tolerance", type=float, default=0.25, help="Suchradius um Time-Selection-Grenzen in Sekunden")
    parser.add_argument("--steps-per-second", type=float, default=40.0, help="OSC-Nachrichten pro Sekunde")
    parser.add_argument(
        "--curve",
        choices=("linear", "smoothstep", "parabolic", "exponential", "polar"),
        default="smoothstep",
        help="Interpolationskurve",
    )
    parser.add_argument(
        "--scripts-dir",
        type=Path,
        default=Path("~/Library/Application Support/REAPER/Scripts"),
        help="Ordner fuer temporaere REAPER Lua-Dateien",
    )
    return parser


def main() -> int:
    args = build_arg_parser().parse_args()

    if args.worker:
        return run_worker(args.command_dir)

    try:
        from pythonosc.udp_client import SimpleUDPClient

        if args.snapshot_file:
            snapshot = read_snapshot_file(args.snapshot_file)
        else:
            reaper_client = ReaperWebClient(args.reaper_host, args.reaper_port, args.scripts_dir)
            snapshot = reaper_client.read_snapshot()
        duration = snapshot.selection_end - snapshot.selection_start
        if duration <= 0:
            raise RuntimeError("Bitte eine Time Selection zwischen zwei Ambi-Markern setzen.")

        motion_start = snapshot.motion_start if snapshot.motion_start is not None else snapshot.selection_start
        motion_end = snapshot.motion_end if snapshot.motion_end is not None else snapshot.selection_end

        client = SimpleUDPClient(args.ambi_host, args.ambi_port)
        if args.series:
            segments = build_series_segments(snapshot.markers, motion_start, motion_end, args.marker_tolerance)
            print(
                f"{SCRIPT_NAME}: series {len(segments)} segments | "
                f"{duration:.3f}s | udp://{args.ambi_host}:{args.ambi_port}"
            )
            send_series_motion(client, segments, args.steps_per_second, args.curve)
            print("Fertig.")
            return 0

        if args.polyphonic:
            pairs = polyphonic_pairs(snapshot.markers, motion_start, motion_end, args.marker_tolerance)
            source_list = ", ".join(pair[1].source for pair in pairs)
            print(
                f"{SCRIPT_NAME}: polyphonic [{source_list}] | "
                f"{duration:.3f}s | udp://{args.ambi_host}:{args.ambi_port}"
            )
            send_polyphonic_motion(client, pairs, duration, args.steps_per_second, args.curve)
            print("Fertig.")
            return 0

        start_marker, start_point = nearest_ambi_marker(
            snapshot.markers,
            motion_start,
            args.marker_tolerance,
        )
        end_marker, end_point = nearest_ambi_marker(
            snapshot.markers,
            motion_end,
            args.marker_tolerance,
        )

        print(
            f"{SCRIPT_NAME}: {start_marker.name!r} -> {end_marker.name!r} | "
            f"{duration:.3f}s | udp://{args.ambi_host}:{args.ambi_port}"
        )
        send_motion(client, start_point, end_point, duration, args.steps_per_second, args.curve)
        print("Fertig.")
        return 0
    except Exception as exc:
        print(f"Fehler: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
