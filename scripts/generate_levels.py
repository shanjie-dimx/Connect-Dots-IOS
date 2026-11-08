#!/usr/bin/env python3
"""Generates the 120 levels and a reference solution for each one.

Every level is accepted only after a full solution has been found and replayed through a
port of ConnectDots/Core (Game.pointerDown/Move and validateSolution), so all levels are solvable.

Trickiness (why some connect-the-dots boards stump people):
  1. Straight-line bait — the obvious chords between same-color dots cross, so the
     shortest-looking moves are illegal.
  2. Cage traps — connecting one pair near-straight puts another pair's ends on opposite
     sides of that chord, "caging" it unless someone wraps around the rim.
  3. Shortest-path traps — taking the geometrically shortest legal corridor for a color
     leaves the rest of the board unsolvable; at least one color must deliberately detour.
  4. Forced wrap — the real solution hugs the circle edge, not the open middle.

The generator scores layouts on those signals and raises the floors as levels progress,
while keeping the first few boards as a gentle tutorial.

Writes:
  ConnectDots/Core/Levels.swift
  Tests/ConnectDotsCoreTests/solutions.json

Usage: python3 scripts/generate_levels.py
"""

import json
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LEVEL_COUNT = 120
SEED = 20261108
MAX_TRIES = 3500

# Mirrors ConnectDots/Core/Geometry.swift.
DOT_RADIUS = 0.085
LINE_WIDTH = 0.06
HALF_WIDTH = LINE_WIDTH / 2
LINE_SEPARATION = LINE_WIDTH * 0.95
DOT_CLEARANCE = DOT_RADIUS + HALF_WIDTH
BOARD_LIMIT = 1 - HALF_WIDTH

# Mirrors ConnectDots/Core/Game.swift.
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
MIN_PAIR_DIST = 0.50


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
    """Port of ConnectDots/Core/Game.swift, used to replay the reference solutions."""

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
        self.midring = [k for k, p in self.nodes.items() if 0.48 <= hypot(*p) <= 0.72]

    def neighbours(self, k):
        i, j = k
        for nk in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
            if nk in self.nodes:
                yield nk


GRID_NODES = Grid()


def route_all(dots, keys, rng, attempts, prefer_short_first=None):
    """Routes every color on the grid without crossings. Returns {color: [node keys]} or None.

    prefer_short_first, when set, is a color that is routed first with flat weights so it
    takes a near-shortest corridor — used to detect shortest-path traps.
    """
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
        rest = [c for c in colors if c not in chords_first and c != prefer_short_first]
        rng.shuffle(rest)
        if prefer_short_first is not None and prefer_short_first in colors:
            # Greedy bait color first, then rim chords, then the rest.
            order = [prefer_short_first] + [c for c in chords_first if c != prefer_short_first] + rest
        else:
            order = chords_first + rest
        if prefer_short_first is not None:
            weights = flat
        else:
            weights = {k: 1 + rng.random() * 0.6 for k in GRID_NODES.nodes}
        used = set()
        result = {}
        ok = True
        for c in order:
            start, goal = ends[c]
            blocked = used | bad_nodes[c]
            # Flat weights for the bait color so it takes the greedy corridor.
            w = flat if c == prefer_short_first else weights
            path = shortest(start, goal, set(), blocked, bad_edges[c], w)
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


def pair_segments(dots):
    colors = sorted(set(c for (_, _, c) in dots))
    return {c: [(x, y) for (x, y, cc) in dots if cc == c] for c in colors}


def straight_conflicts(dots):
    """How many obstacles the naive straight-line solution runs into."""
    seg = pair_segments(dots)
    colors = list(seg)
    count = 0
    for i, a in enumerate(colors):
        for b in colors[i + 1:]:
            if seg_seg_dist(seg[a][0], seg[a][1], seg[b][0], seg[b][1]) < LINE_SEPARATION:
                count += 1
        for (x, y, cc) in dots:
            if cc != a and point_seg_dist((x, y), seg[a][0], seg[a][1]) < DOT_CLEARANCE:
                count += 1
    return count


def straight_crossings(dots):
    """How many pairs of colors have crossing straight chords — the classic bait."""
    seg = pair_segments(dots)
    colors = list(seg)
    count = 0
    for i, a in enumerate(colors):
        for b in colors[i + 1:]:
            if segments_intersect(seg[a][0], seg[a][1], seg[b][0], seg[b][1]):
                count += 1
    return count


def cage_traps(dots):
    """Count (A, B) where A's straight chord separates B's endpoints.

    Drawing A near-straight then "cages" B unless B wraps around — the viral-puzzle trap.
    Crossing chords count too: the naive move for A blocks the naive move for B.
    """
    seg = pair_segments(dots)
    colors = list(seg)
    count = 0
    for a in colors:
        a0, a1 = seg[a]
        for b in colors:
            if a == b:
                continue
            b0, b1 = seg[b]
            if side(a0, a1, b0) != side(a0, a1, b1) or segments_intersect(a0, a1, b0, b1):
                count += 1
    return count


def shortest_path_traps(dots, keys, rng):
    """How many colors, if greedily given their shortest corridor first, make the rest unsolvable."""
    colors = sorted(set(c for (_, _, c) in dots))
    traps = 0
    for c in colors:
        # A few attempts with this color forced shortest-first: if all fail, it's a trap.
        if route_all(dots, keys, rng, attempts=4, prefer_short_first=c) is None:
            traps += 1
    return traps


def max_pair_detour(solution):
    """Largest path-length / chord-length ratio among colors — forced wraps show up here."""
    best = 1.0
    for pts in solution.values():
        straight = dist(pts[0], pts[-1])
        if straight < 1e-9:
            continue
        best = max(best, path_length(pts) / straight)
    return best


def spec(i):
    """Difficulty settings for zero-based level index i."""
    pairs = min(10, 3 + i * 8 // LEVEL_COUNT)
    t = i / (LEVEL_COUNT - 1)

    # Soft tutorial: learn the rules before the traps.
    if i < 4:
        return {
            "pairs": 3,
            "rim": 0,
            "chords": 0,
            "motif": "scatter",
            "min_conflicts": 0 if i < 2 else 1,
            "max_conflicts": 1 if i < 3 else 2,
            "min_crossings": 0,
            "min_cages": 0,
            "min_traps": 0,
            "min_detour": 1.0,
            "min_max_pair_detour": 1.0,
        }

    # Early viral-style boards: few pairs, high interlocking.
    if i < 15:
        return {
            "pairs": 3,
            "rim": 0 if i < 8 else 1 + (i >= 12),
            "chords": 0,
            "motif": "interleave",
            "min_conflicts": 2 if i < 8 else 3,
            "max_conflicts": 99,
            "min_crossings": 1 if i < 6 else 2,
            "min_cages": 1 if i < 8 else 2,
            "min_traps": 0,
            "min_detour": 1.15 if i < 8 else 1.25,
            "min_max_pair_detour": 1.2 if i < 8 else 1.35,
        }

    chords = 0 if i < 25 else 1 if i < 60 else 2 if i < 95 else 3
    # Crowded boards need fewer rim blockers or routing collapses.
    rim_share = 0.16 + (0.42 if pairs <= 7 else 0.28) * t
    rim = max(1, round(pairs * 2 * rim_share)) - 2 * chords
    rim = max(0, rim)
    # Interleave bait while the board is open; crowd later levels with mixed scatter.
    if pairs <= 5:
        motif = "interleave"
    elif pairs <= 7:
        motif = "mixed"
    else:
        motif = "scatter"
    # Trickiness floors rise through mid-game, then ease so 8–10 pair boards still fill.
    mid = min(1.0, (i - 15) / 60)
    late_ease = 1.0 if pairs <= 7 else (0.55 if pairs <= 8 else 0.35)
    return {
        "pairs": pairs,
        "rim": rim,
        "chords": chords,
        "motif": motif,
        "min_conflicts": max(2, round((2 + mid * (pairs + 1)) * late_ease)),
        "max_conflicts": 99,
        "min_crossings": max(1, round(min(pairs - 1, 1 + mid * (pairs - 1)) * late_ease)),
        "min_cages": max(1, round((1 + mid * pairs) * late_ease)),
        # Shortest-path traps are expensive to search for; use crossings/cages/detour instead.
        "min_traps": 0,
        "min_detour": 1.15 + 0.45 * mid * late_ease,
        "min_max_pair_detour": 1.25 + 0.55 * mid * late_ease,
    }


def rim_node_near(angle, rng):
    best, best_d = None, 9.0
    for k in GRID_NODES.rim:
        p = GRID_NODES.nodes[k]
        d = abs(math.remainder(math.atan2(p[1], p[0]) - angle, 2 * math.pi)) + rng.random() * 0.02
        if d < best_d:
            best, best_d = k, d
    return best


def ring_node_near(angle, pool, rng):
    best, best_d = None, 9.0
    for k in pool:
        p = GRID_NODES.nodes[k]
        d = abs(math.remainder(math.atan2(p[1], p[0]) - angle, 2 * math.pi)) + rng.random() * 0.03
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


def interleaved_color_order(pairs, rng):
    """Color sequence around a ring that creates many crossing chords.

    The viral 3-pair board is essentially color order [0,1,2,0,1,2] around a circle:
    every straight chord crosses every other. For more pairs we build a round-robin
    interleave, then optionally swap a little for variety.
    """
    order = []
    for slot in range(2):
        colors = list(range(pairs))
        rng.shuffle(colors)
        order.extend(colors)
    # Round-robin alternate: 0,1,2,...,0,1,2,... is the strongest bait.
    if rng.random() < 0.7:
        order = list(range(pairs)) + list(range(pairs))
        # Rotate so it doesn't always start at color 0.
        rot = rng.randrange(pairs)
        order = order[rot:] + order[:rot]
    return order


def place_interleaved(s, rng):
    """Place pairs on one or two rings with interleaved angular order — high crossing bait."""
    pairs, chords, rim = s["pairs"], s["chords"], s["rim"]
    # Rim-to-rim chords still use the non-crossing matching so the board stays solvable.
    chosen = []
    keys = []

    def free(p):
        return all(dist(p, (x, y)) >= MIN_DOT_GAP for (x, y, _) in chosen)

    chord_count = chords
    free_pairs = pairs - chord_count
    if free_pairs <= 0 and chord_count == 0:
        return None, None

    if chord_count:
        for _ in range(100):
            angles = sorted(rng.uniform(-math.pi, math.pi) for _ in range(2 * chord_count))
            gaps = [math.remainder(angles[(i + 1) % len(angles)] - angles[i], 2 * math.pi) % (2 * math.pi) for i in range(len(angles))]
            if min(gaps) > 0.45:
                break
        else:
            return None, None
        matching = non_crossing_matching(list(range(2 * chord_count)), rng)
        for c, (i, j) in enumerate(matching):
            for a in (angles[i], angles[j]):
                k = rim_node_near(a, rng)
                p = GRID_NODES.nodes[k]
                if not free(p):
                    return None, None
                chosen.append((p[0], p[1], c))
                keys.append(k)

    chord_lines = [((chosen[2 * c][0], chosen[2 * c][1]), (chosen[2 * c + 1][0], chosen[2 * c + 1][1])) for c in range(chord_count)]

    if free_pairs:
        # Stagger angles evenly, then jitter — evenly spaced rings maximize mutual crossings.
        base = rng.uniform(-math.pi, math.pi)
        step = 2 * math.pi / (2 * free_pairs)
        angles = [base + step * n + rng.uniform(-0.08, 0.08) for n in range(2 * free_pairs)]
        color_order = interleaved_color_order(free_pairs, rng)
        # Map local color ids onto global ids after chords.
        color_order = [c + chord_count for c in color_order]

        # Decide which slots sit on the hard rim (cannot go around).
        rim_slots = min(rim, 2 * free_pairs)
        rim_flags = [True] * rim_slots + [False] * (2 * free_pairs - rim_slots)
        rng.shuffle(rim_flags)

        pending = {c: [] for c in range(chord_count, pairs)}
        for angle, color, on_rim in zip(angles, color_order, rim_flags):
            pool = GRID_NODES.rim if on_rim else (GRID_NODES.midring if rng.random() < 0.75 else GRID_NODES.interior)
            placed = False
            for _ in range(80):
                k = ring_node_near(angle, pool, rng) if pool is not GRID_NODES.interior else rng.choice(pool)
                if k is None:
                    continue
                p = GRID_NODES.nodes[k]
                if not free(p):
                    continue
                if pending[color] and dist(p, pending[color][0]) < MIN_PAIR_DIST:
                    continue
                if pending[color] and any(side(a, b, p) != side(a, b, pending[color][0]) for a, b in chord_lines):
                    continue
                chosen.append((p[0], p[1], color))
                keys.append(k)
                pending[color].append(p)
                placed = True
                break
            if not placed:
                return None, None
        if any(len(v) != 2 for v in pending.values()):
            return None, None

    for c in range(pairs):
        a, b = [(x, y) for (x, y, cc) in chosen if cc == c]
        if dist(a, b) < MIN_PAIR_DIST:
            return None, None
    return chosen, keys


def place_scatter(s, rng):
    """Original random placement — used for the tutorial and as a fallback."""
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
                    if dist(p, first) < MIN_PAIR_DIST:
                        continue
                    if any(side(a, b, p) != side(a, b, first) for a, b in chord_lines):
                        continue
                break
            else:
                return None, None
            chosen.append((p[0], p[1], c))
            keys.append(k)
            first = p
    for c in range(pairs):
        a, b = [(x, y) for (x, y, cc) in chosen if cc == c]
        if dist(a, b) < MIN_PAIR_DIST:
            return None, None
    return chosen, keys


def place(s, rng):
    """Places dots for one level. Motif chooses interleaved bait vs scatter."""
    motif = s.get("motif", "scatter")
    if motif == "interleave":
        return place_interleaved(s, rng)
    if motif == "mixed":
        return place_interleaved(s, rng) if rng.random() < 0.55 else place_scatter(s, rng)
    return place_scatter(s, rng)


def path_length(pts):
    return sum(dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def make_level(i, rng=None):
    rng = rng or random.Random(SEED * 1000 + i)
    base = spec(i)
    best = None
    for attempt in range(MAX_TRIES):
        # Gradually relax trickiness floors so late crowded boards still fill.
        relax = 0
        if attempt > MAX_TRIES * 0.45:
            relax = 1
        if attempt > MAX_TRIES * 0.75:
            relax = 2
        s = dict(base)
        if relax:
            s["min_conflicts"] = max(0, base["min_conflicts"] - relax)
            s["min_crossings"] = max(0, base["min_crossings"] - relax)
            s["min_cages"] = max(0, base["min_cages"] - relax * 2)
            s["min_traps"] = 0 if relax >= 2 else base["min_traps"]
            s["min_detour"] = max(1.0, base["min_detour"] - 0.12 * relax)
            s["min_max_pair_detour"] = max(1.0, base["min_max_pair_detour"] - 0.15 * relax)
            if relax >= 2 and s["pairs"] >= 8:
                s["motif"] = "scatter"
                s["rim"] = max(0, base["rim"] - 1)
        dots, keys = place(s, rng)
        if dots is None:
            continue
        if chords_interleave(dots):
            continue
        conflicts = straight_conflicts(dots)
        if not (s["min_conflicts"] <= conflicts <= s["max_conflicts"]):
            continue
        crossings = straight_crossings(dots)
        if crossings < s["min_crossings"]:
            continue
        cages = cage_traps(dots)
        if cages < s["min_cages"]:
            continue
        route_attempts = 48 if s["pairs"] >= 8 else 36
        routes = route_all(dots, keys, rng, attempts=route_attempts)
        if routes is None:
            continue
        solution = {c: compress([GRID_NODES.nodes[k] for k in r]) for c, r in routes.items()}
        straight = sum(dist(solution[c][0], solution[c][-1]) for c in solution)
        routed = sum(path_length(solution[c]) for c in solution)
        detour = routed / straight if straight else 1.0
        if detour < s["min_detour"]:
            continue
        pair_detour = max_pair_detour(solution)
        if pair_detour < s["min_max_pair_detour"]:
            continue
        if replay(dots, solution) is None:
            continue
        # Trap check is costly; only run when the level requires traps.
        traps = 0
        if s["min_traps"] > 0:
            traps = shortest_path_traps(dots, keys, random.Random(rng.random()))
            if traps < s["min_traps"]:
                continue
        score = (
            4.0 * crossings
            + 3.5 * cages
            + 6.0 * traps
            + 1.5 * base["chords"]
            + 0.35 * base["rim"]
            + 5.0 * (detour - 1)
            + 2.0 * (pair_detour - 1)
        )
        cand = {
            "dots": dots,
            "solution": solution,
            "score": score,
            "spec": base,
            "crossings": crossings,
            "cages": cages,
            "traps": traps,
            "detour": detour,
        }
        # Keep a short hunt for bait on open mid-game boards; otherwise take the first hit.
        if best is None or cand["score"] > best["score"]:
            best = cand
        hunt_budget = 0 if i < 8 or base["pairs"] >= 7 else int(MAX_TRIES * 0.12)
        if best is not None and (attempt >= hunt_budget or crossings >= base["min_crossings"] + 1):
            return best
    if best is not None:
        return best
    # No solvable layout found in time: leave the level blank so the app shows it as coming soon.
    return {"dots": [], "solution": {}, "score": 1e9, "spec": base, "crossings": 0, "cages": 0, "traps": 0, "detour": 1.0}


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
            # Keep the soft tutorial prefix in place; sort the rest of the 3-pair band by score.
            tutorial = group[:4]
            rest = sorted(group[4:], key=lambda lv: lv["score"])
            ordered += tutorial + rest
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
    with open(os.path.join(ROOT, "ConnectDots/Core/Levels.swift"), "w") as f:
        f.write("\n".join(out))

    solutions = []
    for lv in ordered:
        solutions.append({str(c): [[r4(x), r4(y)] for (x, y) in pts] for c, pts in sorted(lv["solution"].items())})
    with open(os.path.join(ROOT, "Tests/ConnectDotsCoreTests/solutions.json"), "w") as f:
        json.dump(solutions, f, separators=(",", ":"))
        f.write("\n")

    for n, lv in enumerate(ordered, start=1):
        s = lv["spec"]
        print(
            "level %3d  pairs %2d  rim %2d  chords %d  cross %d  cage %d  traps %d  detour %.2f  score %.1f"
            % (n, s["pairs"], s["rim"], s["chords"], lv.get("crossings", 0), lv.get("cages", 0), lv.get("traps", 0), lv.get("detour", 1.0), lv["score"])
        )


if __name__ == "__main__":
    main()
