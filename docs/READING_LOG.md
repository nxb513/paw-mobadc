# READING_LOG - full-text reading of every cited work (paper for IJDC)

Rule (user, 2026-10-07): a work is cited only if its **full text was read**; a work that cannot be read is downloaded by
the user (into `refs/`, git-ignored) or not cited; a work read and found not relevant is not cited; one statement may
carry several citations, each of which must support it. Each entry: the version read, what it supports (with its
section / equation / figure), and what it must not be cited for. Status: **READ** (full text read), **TO GET** (closed;
the user downloads it), **DROP** (read, not relevant / not needed).

## READ

### sreenath2013 - Sreenath, Lee, Kumar, CDC 2013
- Version read: author copy, hybrid-robotics.berkeley.edu/publications/CDC2013.pdf (6 pp.), 2026-10-07.
- Supports: coordinate-free model of a quadrotor with a cable-suspended point-mass load on SE(3) x S^2 when the cable
  is taut, 8 DOF / 4 underactuated, derived with the Lagrange-d'Alembert principle (Sec. II-A, eqs. (5)-(10)); zero
  tension = load in free fall, the system is hybrid (Sec. II-B, II-C); differential flatness with load position and yaw
  as flat outputs (Sec. III, Lemma 1); geometric controllers for quadrotor attitude, load attitude and load position
  with almost-global exponential stability / attractivity (Sec. IV, Props. 1-4); simulations only, no wind or drag.
- Use for: the taut-cable model our plant extends; the hybrid (slack) case we flag and exclude; load-attitude feedback
  as the swing-damping alternative.
- Not for: wind, drag, disturbance estimation, experiments. Page numbers of the IEEE version: not in this copy.

### smeur2018 - Smeur, de Croon, Chu, Control Eng. Pract. 73 (2018) 79-90
- Version read: arXiv:1701.07254v2 (accepted version), 2026-10-07.
- Supports: cascaded INDI - the outer loop increments thrust vector from the difference between desired and measured
  (filtered) acceleration, eq. (19); disturbances and control forces are both seen by the accelerometer (Sec. 1, 3);
  every signal of the increment filtered with the same second-order filter, eq. (4), to keep them synchronised
  (Sec. 2, 4.5), filter choice trades disturbance-rejection speed against noise (Sec. 4.5); windtunnel 10 m/s: max
  position deviation 0.21 m vs 1.51 m for PID (Sec. 5.1); outdoor takeoff ~5.1 m/s wind: 0.24 m vs 0.85 m (Sec. 6.1);
  **the outer loop is sensitive to accelerometer bias - a measurement offset becomes an acceleration offset and a
  position offset** (Sec. 4.6); **actuator dynamics are crucial for stability; gains designed for one actuator time
  constant can be unstable for another** (Sec. 2.1); onboard Pitot tubes / multi-probe sensors as wind measurement,
  airspeed sensors unreliable at low airspeed (Sec. 1); no aerodynamic drag model is used (Sec. 3).
- Use for: INDI-DE as the comparison method (outer-loop INDI disturbance estimate); bias sensitivity of
  acceleration-based estimates; dependence of gain stability on actuator lag; wind sensing on board.

### byun2021 - Byun, Makiharju, Mueller, ICUAS 2021
- Version read: arXiv:2003.02974v3, 2026-10-07.
- Supports: IMU-based disturbance-force estimate f_d = F[m R a_meas - c e3] (eq. (7)) used in feedback; the estimate
  recorded against position on the outbound flight and fed forward on the return flight (Sec. III); 43 % lower RMSE
  at 1 m/s in a ~6 m/s jet, 14 % in a complex flow (Sec. IV-D, V); the strategy assumes a flow that varies over space
  but is steady in time, and fails when the flow is unsteady (Sec. IV-D-3); laboratory jet / fan flows.
- Use for: acceleration-based disturbance estimation in multirotor control; advance (recorded) knowledge of the
  disturbance fed forward; laboratory flows varying in space, not in time (contrast with measured outdoor wind).

### oconnell2022 - O'Connell et al., Science Robotics 7 (2022) eabm6597 (Neural-Fly)
- Version read: arXiv:2205.06908v2 (accepted version), 2026-10-07.
- Supports: learned wind-invariant basis + composite adaptation (Sec. 1, 2); Caltech Real Weather Wind Tunnel, uniform
  winds up to 12.1 m/s and a time-varying wind, figure-8 (Results); residual-force estimators (INDI, L1) are limited
  by system delay, measurement noise and controller rate - reduced lag vs amplified noise (Introduction, Results);
  remaining error attributed to code / communication delay of 15-30 ms and attitude-tracking delay (Discussion);
  mean errors e.g. INDI 7.3 / 6.1 / 7.5 / 12.7 cm at 0 / 4.2 / 8.5 / 12.1 m/s (Table 1).
- Use for: wind rejection by learned / estimated aerodynamic force; estimation lag and loop delay as the limit of
  measurement-based disturbance estimates.

### munafo2017 - Munafo et al., Nature Human Behaviour 1 (2017) 0021
- Version read: published PDF (nature.com), 2026-10-07.
- Supports: pre-registration addresses publication bias and analytical flexibility (outcome switching, P-hacking); its
  strongest form pre-specifies design, primary outcome and analysis plan before the outcomes are known, keeping
  analytical decisions data-independent and separating confirmatory from exploratory analysis (section "Promoting study
  pre-registration"); Registered Reports.
- Use for: the registration of every claim before its data were opened; post-hoc findings labelled as exploratory.

### chen2004 - W.-H. Chen, IEEE/ASME Trans. Mechatronics 9(4) (2004) 706-710
- Version read: author copy, Loughborough repository (figshare 9224018), 2026-10-07.
- Supports: two-stage DOBC design - controller designed as if the disturbance were measurable, then a disturbance
  observer replaces it by its estimate (Sec. II); disturbance generated by a linear neutrally stable exogenous system
  xi' = A xi, d = C xi, covering unknown loads and harmonics (Sec. I, III, eq. (2)); nonlinear DO with global
  exponential convergence (Thms 1-2); semiglobal exponential stability of the composite controller (Thm 3).
- Use for: the DO with an exosystem (internal model) on which Guo's DO and our prediction through the exosystem rest.

### chen2016 - Chen, Yang, Guo, Li, IEEE Trans. Ind. Electron. 63(2) (2016) 1083-1095
- Version read: published open-access PDF (IEEE Xplore, CC BY 3.0), 2026-10-07.
- Supports: a measurable disturbance can be attenuated by feedforward; when it cannot be measured it is estimated and
  compensated (Sec. I-A); DOBC, ESO/ADRC, UIO/DAC, UDE, EID, GPIO unified as disturbance estimation and attenuation;
  low-pass filter bandwidth trades disturbance attenuation against noise sensitivity (Sec. II-A); ESO needs only the
  relative degree (Sec. II-B); exosystem-based NDOB for harmonic / periodic disturbances (Sec. III-A); CHADC - lumping
  several disturbances into one equivalent disturbance can be conservative, knowledge of each disturbance should be
  used (Sec. IV-D); need for fair and detailed comparisons to quantify the true benefits (Sec. VI-B-4).
- Use for: the disturbance-estimation family of MOBADC; measured disturbances fed forward; separate modelling of the
  disturbance paths; the case for a rigorous comparison.

## DROP

### shi2019 - Shi et al., ICRA 2019 (Neural Lander)
- Version read: arXiv:1811.08027v2, 2026-10-07. Learned ground-effect residual for landing; no wind, no slung load -
  not needed for any statement of the paper (wind learning is covered by oconnell2022).
