#!/usr/bin/env python3
"""Generates the 120 levels and a reference solution for each one.

Every level is accepted only after a full solution has been found and replayed through a
port of ColorLink/Core (Game.pointerDown/Move and validateSolution), so all levels are solvable.

Writes:
  ColorLink/Core/Levels.swift
  Tests/ColorLinkCoreTests/solutions.json

Usage: python3 scripts/generate_levels.py
"""

import json
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LEVEL_COUNT = 120
SEED = 20261107
MAX_TRIES = 6000

# Mirrors ColorLink/Core/Geometry.swift.
DOT_RADIUS = 0.085
LINE_WIDTH = 0.06
HALF_WIDTH = LINE_WIDTH / 2
LINE_SEPARATION = LINE_WIDTH * 0.95
DOT_CLEARANCE = DOT_RADIUS + HALF_WIDTH
BOARD_LIMIT = 1 - HALF_WIDTH

# Mirrors ColorLink/Core/Game.swift.
STEP = 0.02
MIN_STEP = 0.012
BACKTRACK_RADIUS = 0.045
BACKTRACK_MIN_ARC = 0.12
PICK_RADIUS = DOT_RADIUS * 1.8

# Routing grid. Paths of different colors never share a node, and with 4-neighbour moves two
# such paths stay at least GRID apart, which is more than LINE_SEPARATION.
GRID = 0.065
NODE_LIMIT = 0.955
ROUTE_DOT_CLEARANCE = DOT_CLEARANCE + 0.012

# A dot whose center is farther out than BOARD_LIMIT - DOT_CLEARANCE leaves no room for a line
# between it and the rim, so lines cannot go around it.
RIM_MIN = 0.87
RIM_MAX = 0.91
INTERIOR_MAX = 0.74
MIN_DOT_GAP = 0.25


def hypot(x, y):
    return math.sqrt(x * x + y * y)


def dist(a, b):
    return hypot(a[0] - b[0], a[1] - b[1])


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def point_seg_dist(p, a, b):
    dx = b[0] - a[0]
    dy = b[1] - a[1]
    len2 = dx * dx + dy * dy
    t = 0 if len2 == 0 else ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / len2
    t = max(0, min(1, t))
    return hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy))


def cross(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def segments_intersect(a, b, c, d):
    d1 = cross(c, d, a)
    d2 = cross(c, d, b)
    d3 = cross(a, b, c)
    d4 = cross(a, b, d)
    return ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0))


def seg_seg_dist(a, b, c, d):
    if segments_intersect(a, b, c, d):
        return 0
    return min(point_seg_dist(a, c, d), point_seg_dist(b, c, d), point_seg_dist(c, a, b), point_seg_dist(d, a, b))


def inside_board(p):
    return hypot(p[0], p[1]) <= BOARD_LIMIT


def segment_conflict(a, b, color, dots, paths):
    if not inside_board(b) or not inside_board(a):
        return "edge"
    for (x, y, c) in dots:
        if c != color and point_seg_dist((x, y), a, b) < DOT_CLEARANCE:
            return "dot"
    for other, pts in paths.items():
        if other == color:
            continue
        for i in range(len(pts) - 1):
            if seg_seg_dist(a, b, pts[i], pts[i + 1]) < LINE_SEPARATION:
                return "line"
    return None


def validate_solution(dots, paths):
    colors = sorted(set(c for (_, _, c) in dots))
    for color in colors:
        pts = paths.get(color)
        if not pts or len(pts) < 2:
            return "color %d not connected" % color
        ends = [(x, y) for (x, y, c) in dots if c == color]
        first, last = pts[0], pts[-1]
        ok = (dist(first, ends[0]) < 1e-9 and dist(last, ends[1]) < 1e-9) or (
            dist(first, ends[1]) < 1e-9 and dist(last, ends[0]) < 1e-9
        )
        if not ok:
            return "color %d has wrong endpoints" % color
        for i in range(len(pts) - 1):
            reason = segment_conflict(pts[i], pts[i + 1], color, dots, paths)
            if reason:
                return "color %d segment %d: %s" % (color, i, reason)
    return None


class Game:
    """Port of ColorLink/Core/Game.swift, used to replay the reference solutions."""

    def __init__(self, dots):
        self.dots = dots
        self.paths = {}
        self.active = None

    def dot_at(self, p):
        best, best_d = None, PICK_RADIUS
        for dot in self.dots:
            d = dist((dot[0], dot[1]), p)
            if d < best_d:
                best, best_d = dot, d
        return best

    def pointer_down(self, p):
        dot = self.dot_at(p)
        if dot is None:
            return False
        target = next((d for d in self.dots if d[2] == dot[2] and d != dot), None)
        if target is None:
            return False
        replaced = self.paths.pop(dot[2], None)
        self.active = {"color": dot[2], "target": target, "points": [(dot[0], dot[1])], "replaced": replaced}
        return True

    def pointer_move(self, p):
        a = self.active
        if a is None:
            return None
        pts = a["points"]
        origin = pts[-1]
        steps = max(1, int(math.ceil(dist(origin, p) / STEP)))
        target = (a["target"][0], a["target"][1])
        for i in range(1, steps + 1):
            q = lerp(origin, p, i / steps)
            if self._backtrack(pts, q):
                continue
            prev = pts[-1]
            reaches = dist(q, target) <= DOT_RADIUS
            if dist(prev, q) < MIN_STEP and not reaches:
                continue
            if self._conflict(prev, q, a):
                return "blocked"
            pts.append(q)
            if reaches:
                pts.append(target)
                self.paths[a["color"]] = pts
                self.active = None
                return "connected"
        return "moved"

    def pointer_up(self):
        a = self.active
        if a is None:
            return
        if a["replaced"] is not None:
            self.paths[a["color"]] = a["replaced"]
        self.active = None

    def _backtrack(self, pts, q):
        if len(pts) < 2:
            return False
        arc = 0.0
        arc_from_end = [0.0] * len(pts)
        for i in range(len(pts) - 2, -1, -1):
            arc += dist(pts[i], pts[i + 1])
            arc_from_end[i] = arc
        for i in range(len(pts) - 1):
            if arc_from_end[i] < BACKTRACK_MIN_ARC:
                break
            radius = DOT_RADIUS if i == 0 else BACKTRACK_RADIUS
            if dist(pts[i], q) < radius:
                del pts[i + 1:]
                return True
        return False

    def _conflict(self, prev, q, a):
        if segment_conflict(prev, q, a["color"], self.dots, self.paths):
            return True
        pts = a["points"]
        i = 0
        while i + 2 < len(pts):
            if segments_intersect(prev, q, pts[i], pts[i + 1]):
                return True
            i += 1
        return False


def replay(dots, solution):
    """Draws each color in the order GameTests does and returns the committed paths, or None."""
    game = Game(dots)
    for color in sorted(solution, key=str):
        pts = solution[color]
        if not game.pointer_down(pts[0]):
            return None
        result = None
        for p in pts[1:]:
            result = game.pointer_move(p)
            if result != "moved":
                break
        game.pointer_up()
        if result != "connected":
            return None
    if validate_solution(dots, game.paths):
        return None
    return game.paths


def r4(v):
    return round(v, 4) + 0.0


class Grid:
    def __init__(self):
        n = int(NODE_LIMIT / GRID) + 1
        self.nodes = {}
        for i in range(-n, n + 1):
            for j in range(-n, n + 1):
                p = (r4(i * GRID), r4(j * GRID))
                if hypot(*p) <= NODE_LIMIT:
                    self.nodes[(i, j)] = p
        self.rim = [k for k, p in self.nodes.items() if RIM_MIN <= hypot(*p) <= RIM_MAX]
        self.interior = [k for k, p in self.nodes.items() if hypot(*p) <= INTERIOR_MAX]

    def neighbours(self, k):
        i, j = k
        for nk in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
            if nk in self.nodes:
                yield nk


GRID_NODES = Grid()


def route_all(dots, keys, rng, attempts):
    """Routes every color on the grid without crossings. Returns {color: [node keys]} or None."""
    colors = sorted(set(c for (_, _, c) in dots))
    ends = {c: [keys[i] for i, d in enumerate(dots) if d[2] == c] for c in colors}

    reach = int(math.ceil((ROUTE_DOT_CLEARANCE + GRID) / GRID))
    bad_nodes = {c: set() for c in colors}
    bad_edges = {c: set() for c in colors}
    for di, (x, y, dc) in enumerate(dots):
        ci, cj = keys[di]
        for i in range(ci - reach, ci + reach + 1):
            for j in range(cj - reach, cj + reach + 1):
                a = (i, j)
                if a not in GRID_NODES.nodes:
                    continue
                pa = GRID_NODES.nodes[a]
                near = dist(pa, (x, y)) < ROUTE_DOT_CLEARANCE
                blocked = [b for b in GRID_NODES.neighbours(a) if point_seg_dist((x, y), pa, GRID_NODES.nodes[b]) < ROUTE_DOT_CLEARANCE]
                for c in colors:
                    if c == dc:
                        continue
                    if near:
                        bad_nodes[c].add(a)
                    for b in blocked:
                        bad_edges[c].add((a, b))
                        bad_edges[c].add((b, a))

    # Fail fast when a pair cannot be joined even on an empty board.
    flat = {k: 1.0 for k in GRID_NODES.nodes}
    for c in colors:
        if shortest(ends[c][0], ends[c][1], set(), bad_nodes[c], bad_edges[c], flat) is None:
            return None

    chords_first = [c for c in colors if all(hypot(*GRID_NODES.nodes[k]) >= RIM_MIN for k in ends[c])]
    for _ in range(attempts):
        rest = [c for c in colors if c not in chords_first]
        rng.shuffle(rest)
        order = chords_first + rest
        weights = {k: 1 + rng.random() * 0.6 for k in GRID_NODES.nodes}
        used = set()
        result = {}
        ok = True
        for c in order:
            start, goal = ends[c]
            blocked = used | bad_nodes[c]
            path = shortest(start, goal, set(), blocked, bad_edges[c], weights)
            if path is None:
                ok = False
                break
            result[c] = path
            used.update(path)
        if ok:
            return result
    return None


def chords_interleave(dots):
    """True when two rim-to-rim pairs alternate around the rim, which no solution can satisfy."""
    def angle(x, y):
        return math.atan2(y, x)

    chords = []
    for c in sorted(set(d[2] for d in dots)):
        ends = [(x, y) for (x, y, cc) in dots if cc == c]
        if all(hypot(*p) >= RIM_MIN for p in ends):
            a, b = sorted(angle(*p) for p in ends)
            chords.append((a, b))
    for i, (a1, b1) in enumerate(chords):
        for a2, b2 in chords[i + 1:]:
            if (a1 < a2 < b1) != (a1 < b2 < b1):
                return True
    return False


def shortest(start, goal, used, bad, bad_edges, weights):
    import heapq

    gx, gy = GRID_NODES.nodes[goal]
    best = {start: 0.0}
    prev = {}
    heap = [(0.0, 0.0, start)]
    while heap:
        _, cost, k = heapq.heappop(heap)
        if k == goal:
            path = [k]
            while k in prev:
                k = prev[k]
                path.append(k)
            return path[::-1]
        if cost > best.get(k, 1e9):
            continue
        for nk in GRID_NODES.neighbours(k):
            if nk != goal and (nk in used or nk in bad):
                continue
            if (k, nk) in bad_edges:
                continue
            nc = cost + weights[nk]
            if nc < best.get(nk, 1e9):
                best[nk] = nc
                prev[nk] = k
                px, py = GRID_NODES.nodes[nk]
                h = (abs(px - gx) + abs(py - gy)) / GRID
                heapq.heappush(heap, (nc + h, nc, nk))
    return None


def compress(points):
    out = [points[0]]
    for i in range(1, len(points) - 1):
        a, b, c = out[-1], points[i], points[i + 1]
        if abs(cross(a, b, c)) > 1e-12:
            out.append(b)
    out.append(points[-1])
    return out


def straight_conflicts(dots):
    """How many obstacles the naive straight-line solution runs into."""
    colors = sorted(set(c for (_, _, c) in dots))
    seg = {c: [(x, y) for (x, y, cc) in dots if cc == c] for c in colors}
    count = 0
    for i, a in enumerate(colors):
        for b in colors[i + 1:]:
            if seg_seg_dist(seg[a][0], seg[a][1], seg[b][0], seg[b][1]) < LINE_SEPARATION:
                count += 1
        for (x, y, cc) in dots:
            if cc != a and point_seg_dist((x, y), seg[a][0], seg[a][1]) < DOT_CLEARANCE:
                count += 1
    return count


def spec(i):
    """Difficulty settings for zero-based level index i."""
    pairs = min(10, 3 + i * 8 // LEVEL_COUNT)
    t = i / (LEVEL_COUNT - 1)
    if i < 10:
        return {
            "pairs": 3,
            "rim": 0,
            "chords": 0,
            "min_conflicts": 0 if i < 2 else 1,
            "max_conflicts": 1 if i < 5 else 2,
            "min_detour": 1.0,
        }
    chords = 0 if i < 25 else 1 if i < 60 else 2 if i < 95 else 3
    rim_share = 0.15 + 0.45 * t
    rim = max(1, round(pairs * 2 * rim_share)) - 2 * chords
    rim = max(0, rim)
    return {
        "pairs": pairs,
        "rim": rim,
        "chords": chords,
        "min_conflicts": 1 + round(t * (pairs + 3)),
        "max_conflicts": 99,
        "min_detour": 1.0 + 0.35 * t,
    }


def rim_node_near(angle, rng):
    best, best_d = None, 9.0
    for k in GRID_NODES.rim:
        p = GRID_NODES.nodes[k]
        d = abs(math.remainder(math.atan2(p[1], p[0]) - angle, 2 * math.pi)) + rng.random() * 0.02
        if d < best_d:
            best, best_d = k, d
    return best


def non_crossing_matching(items, rng):
    """Random pairing of points listed in rim order such that no two pairs alternate."""
    if not items:
        return []
    m = rng.randrange(len(items) // 2)
    j = 2 * m + 1
    first = (items[0], items[j])
    return [first] + non_crossing_matching(items[1:j], rng) + non_crossing_matching(items[j + 1:], rng)


def side(a, b, p):
    v = cross(a, b, p)
    return 1 if v > 0 else -1


def place(s, rng):
    """Places dots for one level. Rim-to-rim pairs never interleave, and every other pair keeps
    both dots on the same side of each rim-to-rim pair so the level stays solvable."""
    pairs, chords, rim = s["pairs"], s["chords"], s["rim"]
    chosen = []
    keys = []

    def free(p):
        return all(dist(p, (x, y)) >= MIN_DOT_GAP for (x, y, _) in chosen)

    if chords:
        for _ in range(100):
            angles = sorted(rng.uniform(-math.pi, math.pi) for _ in range(2 * chords))
            gaps = [math.remainder(angles[(i + 1) % len(angles)] - angles[i], 2 * math.pi) % (2 * math.pi) for i in range(len(angles))]
            if min(gaps) > 0.45:
                break
        else:
            return None, None
        matching = non_crossing_matching(list(range(2 * chords)), rng)
        for c, (i, j) in enumerate(matching):
            for a in (angles[i], angles[j]):
                k = rim_node_near(a, rng)
                p = GRID_NODES.nodes[k]
                if not free(p):
                    return None, None
                chosen.append((p[0], p[1], c))
                keys.append(k)
    chord_lines = [((chosen[2 * c][0], chosen[2 * c][1]), (chosen[2 * c + 1][0], chosen[2 * c + 1][1])) for c in range(chords)]

    rim_flags = [True] * rim + [False] * (2 * (pairs - chords) - rim)
    rng.shuffle(rim_flags)
    for n, c in enumerate(range(chords, pairs)):
        first = None
        for which in range(2):
            on_rim = rim_flags[2 * n + which]
            pool = GRID_NODES.rim if on_rim else GRID_NODES.interior
            for _ in range(300):
                k = rng.choice(pool)
                p = GRID_NODES.nodes[k]
                if not free(p):
                    continue
                if first is not None:
                    if dist(p, first) < 0.45:
                        continue
                    if any(side(a, b, p) != side(a, b, first) for a, b in chord_lines):
                        continue
                break
            else:
                return None, None
            chosen.append((p[0], p[1], c))
            keys.append(k)
            first = p
    # A pair that is too close together is trivial.
    for c in range(pairs):
        a, b = [(x, y) for (x, y, cc) in chosen if cc == c]
        if dist(a, b) < 0.45:
            return None, None
    return chosen, keys


def path_length(pts):
    return sum(dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def make_level(i, rng=None):
    rng = rng or random.Random(SEED * 1000 + i)
    s = spec(i)
    for _ in range(MAX_TRIES):
        dots, keys = place(s, rng)
        if dots is None:
            continue
        if chords_interleave(dots):
            continue
        conflicts = straight_conflicts(dots)
        if not (s["min_conflicts"] <= conflicts <= s["max_conflicts"]):
            continue
        routes = route_all(dots, keys, rng, attempts=30)
        if routes is None:
            continue
        solution = {c: compress([GRID_NODES.nodes[k] for k in r]) for c, r in routes.items()}
        straight = sum(dist(solution[c][0], solution[c][-1]) for c in solution)
        routed = sum(path_length(solution[c]) for c in solution)
        detour = routed / straight
        if detour < s["min_detour"]:
            continue
        if replay(dots, solution) is None:
            continue
        score = conflicts + 1.5 * s["chords"] + 0.4 * s["rim"] + 4 * (detour - 1)
        return {"dots": dots, "solution": solution, "score": score, "spec": s}
    # No solvable layout found in time: leave the level blank so the app shows it as coming soon.
    return {"dots": [], "solution": {}, "score": 1e9, "spec": s}


def fmt(v):
    s = repr(r4(v))
    return s


def main():
    from multiprocessing import Pool

    with Pool() as pool:
        levels = pool.map(make_level, range(LEVEL_COUNT), chunksize=1)

    # Within each group of levels that share a pair count, put easier layouts first.
    ordered = []
    i = 0
    while i < len(levels):
        j = i
        while j < len(levels) and levels[j]["spec"]["pairs"] == levels[i]["spec"]["pairs"]:
            j += 1
        group = levels[i:j]
        if i == 0:
            ordered += group[:10] + sorted(group[10:], key=lambda lv: lv["score"])
        else:
            ordered += sorted(group, key=lambda lv: lv["score"])
        i = j

    out = ["// Generated by scripts/generate_levels.py. Do not edit by hand.", "", "public let LEVELS: [Level] = ["]
    for n, lv in enumerate(ordered, start=1):
        out.append("    Level(id: %d, dots: [" % n)
        for (x, y, c) in sorted(lv["dots"], key=lambda d: (d[2], d[1], d[0])):
            out.append("        Dot(x: %s, y: %s, color: %d)," % (fmt(x), fmt(y), c))
        out.append("    ]),")
    out.append("]")
    out.append("")
    with open(os.path.join(ROOT, "ColorLink/Core/Levels.swift"), "w") as f:
        f.write("\n".join(out))

    solutions = []
    for lv in ordered:
        solutions.append({str(c): [[r4(x), r4(y)] for (x, y) in pts] for c, pts in sorted(lv["solution"].items())})
    with open(os.path.join(ROOT, "Tests/ColorLinkCoreTests/solutions.json"), "w") as f:
        json.dump(solutions, f, separators=(",", ":"))
        f.write("\n")

    for n, lv in enumerate(ordered, start=1):
        s = lv["spec"]
        print("level %3d  pairs %2d  rim %2d  chords %d  score %.1f" % (n, s["pairs"], s["rim"], s["chords"], lv["score"]))


if __name__ == "__main__":
    main()
