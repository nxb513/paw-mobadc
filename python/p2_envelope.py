#!/usr/bin/env python3
"""
p2_envelope.py -- the P2 operating envelope (docs/REGISTER_P2.md sec 0.10), computed
a priori from the segment wind speed U alone. No simulation, no tracking error.

A segment is inside the envelope when the UAV can hold position against the total
STATIC wind force (body + payload, quadratic drag at U, v = 0):

    F_h(U)   = K_w * U^2 / U_ref * (1 + K)          [N]   (MASTER_PLAN 2.8, 2.8b)
    W        = (m_Q + m_L) * g
    tilt     = atan(F_h / W)          <= 0.8 * TILT_MAX
    thrust   = sqrt(F_h^2 + W^2)      <= 0.8 * F_TOT_MAX,   F_TOT_MAX = 0.9 * plant max

U_max is the largest U meeting both. The payload angle is reported, not used:
    theta_L  = atan(F_wL / (m_L g)),  F_wL = K * K_w * U^2 / U_ref

    python3 python/p2_envelope.py            # the registered table (static, sec 0.10)
    python3 python/p2_envelope.py --u 7.3    # is one segment (U = 7.3 m/s) inside, per (K, m_p)?
    python3 python/p2_envelope.py --traj     # amendment A2 (REGISTER_P2 sec 4.2): + trajectory acceleration

Amendment A2 (proposed after GD3 found the 30 deg clamp active on i0715, REGISTER_P2
sec 4.3): the horizontal force the thrust must supply is the static wind force PLUS
m_tot * a_traj_max, the largest horizontal reference acceleration of the block's
trajectory, taken in phase with the wind (worst case):

    tilt     = atan((F_h + m_tot a) / W)             <= 0.8 * TILT_MAX
    thrust   = sqrt((F_h + m_tot a)^2 + W^2)          <= 0.8 * F_TOT_MAX
    m_tot    = m_Q + m_p,   a = A_TRAJ[trajectory]  (all trajectories fly at constant z)
"""

import argparse
import math

G = 9.81
M_Q = 1.121                    # kg, Guo 2020 A.1 / Quanser QDrone v0.4
K_W = 0.2                      # N/(m/s), locked (core/wind_to_force.m)
U_REF = 5.0                    # m/s, locked anchor V_ref (REGISTER_P2 sec 0.10)
TILT_MAX = math.radians(30.0)  # controller tilt limit
PLANT_MAX = {"nominal (30.67 N, nonlinear thrust model)": 30.67,
             "sensitivity (20.44 N, linear thrust model)": 20.44}
FRAC = 0.8                     # envelope margin on tilt and thrust
KS = (0.0, 0.5, 1.0)
MPS = (0.25, 0.5, 0.65)
# largest horizontal reference acceleration [m/s^2] over the 200 s run, from
# simulink_blocks/trajectory_ref.m with the parameters of core/op_set.m (1 ms grid):
A_TRAJ = {
    "hover": 0.0,
    "circle (Test 4, R 0.8, w 1.575)": 0.8 * 1.575 ** 2,                  # 1.9845, exact
    "T3b fig-8 off-res (A 1.13, w 0.7875)": 1.48915,                      # max |a| on the grid
    "square (D 1.3036, T 1.9399, T_h 1)": 1.3036 * (10 / math.sqrt(3)) / 1.9399 ** 2,  # 2.0000, min-jerk peak
    "T5 multisine (c 0.265218), 0-200 s": 1.82991,                        # max |a| on the grid
}


def u_max(K, m_p, plant_max, a_traj=0.0):
    W = (M_Q + m_p) * G
    f_tilt = math.tan(FRAC * TILT_MAX) * W
    t_lim = FRAC * 0.9 * plant_max
    if t_lim <= W:
        return 0.0, "thrust (hover alone exceeds 0.8*F_TOT_MAX)"
    f_thr = math.sqrt(t_lim ** 2 - W ** 2)
    f_h = min(f_tilt, f_thr) - (M_Q + m_p) * a_traj     # wind force left after the trajectory
    which = "tilt" if f_tilt <= f_thr else "thrust"
    if f_h <= 0:
        return 0.0, which + " (trajectory alone exceeds it)"
    return math.sqrt(f_h * U_REF / (K_W * (1.0 + K))), which


def theta_l(K, m_p, U):
    return math.degrees(math.atan(K * K_W * U ** 2 / U_REF / (m_p * G)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--u", type=float, default=None, help="one segment's U [m/s]")
    ap.add_argument("--traj", action="store_true", help="amendment A2: per-trajectory table")
    a = ap.parse_args()
    if a.traj:
        pm = PLANT_MAX["nominal (30.67 N, nonlinear thrust model)"]
        print(f"Amendment A2 (proposed): U_max [m/s] with the trajectory's acceleration, plant max {pm} N")
        print("  trajectory                               a_max   " + "  ".join(
            f"K{K}/mp{m}" for K in KS for m in MPS))
        for name, acc in A_TRAJ.items():
            row = "  ".join(f"{u_max(K, m, pm, acc)[0]:9.2f}" for K in KS for m in MPS)
            print(f"  {name:<40} {acc:5.3f}   {row}")
        return
    print(f"U_ref = {U_REF} m/s, K_w = {K_W}, m_Q = {M_Q} kg, margins: tilt <= {FRAC}*30 deg = "
          f"{FRAC * 30:.0f} deg, thrust <= {FRAC}*F_TOT_MAX")
    for name, pm in PLANT_MAX.items():
        print(f"\nplant max {name}: F_TOT_MAX = {0.9 * pm:.2f} N, 0.8*F_TOT_MAX = {FRAC * 0.9 * pm:.2f} N")
        print("  K     m_p   U_max[m/s]  binds    theta_L at U_max [deg]")
        for K in KS:
            for m_p in MPS:
                um, which = u_max(K, m_p, pm)
                th = theta_l(K, m_p, um) if um > 0 else float("nan")
                inside = ""
                if a.u is not None:
                    inside = "  inside" if a.u <= um else "  OUTSIDE"
                print(f"  {K:<5} {m_p:<5} {um:10.2f}  {which:<7}  {th:8.1f}{inside}")


if __name__ == "__main__":
    main()
