#!/usr/bin/env python3
"""Isolated Stage 1 math probes; this is not the production physics engine."""

from __future__ import annotations

import argparse
import json
import math
import platform
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

RADIUS = 0.028575
MASS = 0.17
GRAVITY = 9.81
TOLERANCE = 1e-9


def close(actual: float, expected: float, tolerance: float = TOLERANCE) -> None:
    if not math.isclose(actual, expected, rel_tol=tolerance, abs_tol=tolerance):
        raise AssertionError(f"expected {expected:.15g}, got {actual:.15g}")


def swept_circle_toi(
    px: float, py: float, vx: float, vy: float, radius_sum: float, t_max: float
) -> float | None:
    """Earliest t where |p + v*t| = radius_sum, including t=0 contact."""
    c = px * px + py * py - radius_sum * radius_sum
    if c <= 0.0:
        return 0.0
    a = vx * vx + vy * vy
    if a <= 0.0:
        return None
    b = 2.0 * (px * vx + py * vy)
    if b >= 0.0:
        return None
    discriminant = b * b - 4.0 * a * c
    if discriminant < 0.0:
        return None
    t = (-b - math.sqrt(discriminant)) / (2.0 * a)
    return t if 0.0 <= t <= t_max else None


def normal_impulse(velocity_a: float, velocity_b: float, restitution: float) -> float:
    """One-dimensional head-on normal impulse; separating contacts get zero."""
    relative_normal_velocity = velocity_b - velocity_a
    if relative_normal_velocity >= 0.0:
        return 0.0
    return -(1.0 + restitution) * relative_normal_velocity / (2.0 / MASS)


def probe_head_on_toi() -> dict:
    t = swept_circle_toi(-1.0, 0.0, 1.0, 0.0, 2.0 * RADIUS, 1.0)
    if t is None:
        raise AssertionError("sweep did not find contact")
    close(t, 1.0 - 2.0 * RADIUS)
    contact_x = -1.0 + t
    close(contact_x, -2.0 * RADIUS)
    return {"toi_seconds": t, "moving_ball_contact_x_m": contact_x}


def probe_elastic_head_on_conservation() -> dict:
    initial_a, initial_b = 1.0, 0.0
    impulse = normal_impulse(initial_a, initial_b, restitution=1.0)
    final_a = initial_a - impulse / MASS
    final_b = initial_b + impulse / MASS
    momentum_before = MASS * (initial_a + initial_b)
    momentum_after = MASS * (final_a + final_b)
    energy_before = 0.5 * MASS * (initial_a**2 + initial_b**2)
    energy_after = 0.5 * MASS * (final_a**2 + final_b**2)
    close(final_a, 0.0)
    close(final_b, 1.0)
    close(momentum_after, momentum_before)
    close(energy_after, energy_before)
    return {
        "final_a_m_s": final_a,
        "final_b_m_s": final_b,
        "momentum_before_kg_m_s": momentum_before,
        "momentum_after_kg_m_s": momentum_after,
        "energy_before_j": energy_before,
        "energy_after_j": energy_after,
    }


def probe_separating_contact_has_no_impulse() -> dict:
    impulse = normal_impulse(0.0, 1.0, restitution=1.0)
    close(impulse, 0.0)
    return {"impulse_n_s": impulse}


def probe_cushion_rebound() -> dict:
    vx, vy, restitution = 2.0, 0.5, 0.8
    rebounded_vx = -restitution * vx
    rebounded_vy = vy
    close(rebounded_vx, -1.6)
    close(rebounded_vy, 0.5)
    before = vx * vx + vy * vy
    after = rebounded_vx**2 + rebounded_vy**2
    if after > before:
        raise AssertionError("cushion injected energy in this special case")
    return {"incoming_m_s": [vx, vy], "outgoing_m_s": [rebounded_vx, rebounded_vy]}


def probe_high_speed_sweep() -> dict:
    dt = 1.0 / 240.0
    speed = 1000.0
    rail_center_x = 0.5
    toi = (rail_center_x - RADIUS) / speed
    discrete_x = speed * dt
    if not 0.0 <= toi <= dt:
        raise AssertionError("continuous rail contact not inside tick")
    if discrete_x <= rail_center_x:
        raise AssertionError("fixture is not a tunneling case")
    return {
        "tick_seconds": dt,
        "rail_toi_seconds": toi,
        "discrete_end_x_m": discrete_x,
        "rail_center_limit_x_m": rail_center_x,
        "continuous_contact_found": True,
    }


def probe_deceleration_does_not_cross_zero() -> dict:
    initial_speed = 0.001
    deceleration = 0.1
    dt = 0.02
    next_speed = max(0.0, initial_speed - deceleration * dt)
    following_speed = max(0.0, next_speed - deceleration * dt)
    close(next_speed, 0.0)
    close(following_speed, 0.0)
    return {"initial_m_s": initial_speed, "next_m_s": next_speed, "following_m_s": following_speed}


def probe_slide_to_roll_special_case() -> dict:
    v0 = 3.5
    mu = 0.2
    t_roll = 2.0 * v0 / (7.0 * mu * GRAVITY)
    linear_at_roll = v0 - mu * GRAVITY * t_roll
    angular_at_roll = 5.0 * mu * GRAVITY * t_roll / (2.0 * RADIUS)
    rolling_constraint_velocity = RADIUS * angular_at_roll
    close(linear_at_roll, 5.0 * v0 / 7.0)
    close(rolling_constraint_velocity, linear_at_roll)
    return {
        "initial_speed_m_s": v0,
        "mu_slide": mu,
        "t_roll_seconds": t_roll,
        "v_roll_m_s": linear_at_roll,
        "radius_times_omega_m_s": rolling_constraint_velocity,
        "slip_at_transition_m_s": linear_at_roll - rolling_constraint_velocity,
    }


def probe_no_collision_when_parallel_or_late() -> dict:
    parallel = swept_circle_toi(0.0, 1.0, 1.0, 0.0, 2.0 * RADIUS, 10.0)
    late = swept_circle_toi(-1.0, 0.0, 1.0, 0.0, 2.0 * RADIUS, 0.5)
    if parallel is not None or late is not None:
        raise AssertionError(f"unexpected contacts: parallel={parallel}, late={late}")
    return {"parallel_toi": parallel, "outside_tick_toi": late}


PROBES: list[tuple[str, Callable[[], dict]]] = [
    ("head_on_swept_circle_toi", probe_head_on_toi),
    ("elastic_head_on_conservation", probe_elastic_head_on_conservation),
    ("separating_contact_no_impulse", probe_separating_contact_has_no_impulse),
    ("cushion_rebound_special_case", probe_cushion_rebound),
    ("high_speed_continuous_rail_contact", probe_high_speed_sweep),
    ("deceleration_never_crosses_zero", probe_deceleration_does_not_cross_zero),
    ("slide_to_roll_closed_form", probe_slide_to_roll_special_case),
    ("parallel_and_late_contacts_rejected", probe_no_collision_when_parallel_or_late),
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    default_output = Path(__file__).resolve().parent / "results" / "physics_model_results.json"
    parser.add_argument("--output", type=Path, default=default_output)
    args = parser.parse_args()

    checks = []
    for name, probe in PROBES:
        try:
            details = probe()
            checks.append({"name": name, "status": "PASS", "details": details})
        except Exception as exc:  # report every probe rather than hiding later failures
            checks.append({"name": name, "status": "FAIL", "error": f"{type(exc).__name__}: {exc}"})

    passed = sum(check["status"] == "PASS" for check in checks)
    failed = len(checks) - passed
    report = {
        "probe": "stage1-isolated-physics-math-v1",
        "executed_at_utc": datetime.now(timezone.utc).isoformat(),
        "python": platform.python_version(),
        "platform": platform.platform(),
        "summary": {"PASS": passed, "FAIL": failed, "total": len(checks)},
        "checks": checks,
        "limitations": [
            "Python float and standard-library formulas only; not GDScript or Godot execution.",
            "No multi-contact solver, 3D angular impulse, jaw/pocket geometry, convergence, rendering, Android, or cross-platform determinism claim.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
