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

### shi2018 - Shi, Wu, Chou, Electronics 7(6) (2018) 83
- Version read: published open-access HTML (mdpi.com, CC BY 4.0), 2026-10-07.
- Supports: quadrotor with a slung load modelled by Lagrangian mechanics, planar swing, inelastic massless cable;
  **aerodynamic effects on the load neglected by assumption** (Sec. 2.1.1, assumption 3); near hover the load torque on
  the attitude is a sum of sinusoids at sqrt(g/L) and 3 sqrt(g/L) (eq. (26)); traditional ESO handles slowly varying
  disturbances and cannot fully estimate the periodic slung-load disturbance, an internal model in the observer does
  (Sec. 1, 3); HESO + backstepping, bounded estimation and tracking errors (Secs. 3-4); flight test 0.5 kg load on a
  1 m cable: 50.11 % lower RMS pitch error (Sec. 5.2, Table 2).
- Use for: periodic slung-load disturbance and internal-model observers; load aerodynamics neglected in prior work.

### smeur2016 - Smeur, Chu, de Croon, J. Guid. Control Dyn. 39(3) (2016) 450-461
- Version read: accepted author manuscript (TU Delft repository), 2026-10-07.
- Supports: INDI measures angular acceleration so that unmodelled dynamics including gusts are compensated (Sec. I);
  filtering the angular-acceleration estimate introduces a delay that must be synchronised by filtering the input with
  the same filter (Secs. I, III); actuator dynamics are handled by the incremental form (Sec. I); **predictive filtering
  was set aside because it needs more modelling and "disturbances cannot be predicted"** (Sec. I); without the filter
  compensation the vehicle oscillated (Sec. VI); adaptive control effectiveness (Sec. IV).
- Use for: delay in measurement-based disturbance estimation; the contrast between unstructured disturbances and a
  payload force with known structure.

### nosek2018 - Nosek, Ebersole, DeHaven, Mellor, PNAS 115(11) (2018) 2600-2606
- Version read: published full text (PubMed Central PMC5856500), 2026-10-07.
- Supports: prediction vs postdiction; preregistration defines questions and analysis plan before outcomes are
  observed (Abstract, Introduction); a dataset split into exploration and a sealed holdout converts postdictions from
  the first part into predictions for the holdout (Challenge 7); deviations reported transparently keep most of the
  diagnosticity (Challenge 1); for preexisting data the question is who has observed the data and what was
  communicated (Challenge 3).
- Use for: development / held-out design; post-hoc findings confirmed on held-out days; the prior exposure of the
  held-out days stated.

### mendez2022 - Mendez, Whidborne, Chen, ICUAS 2022, pp. 1455-1464 (doi 10.1109/ICUAS54217.2022.9836086)
- Version read: author copy (UCL Discovery 10152959), 2026-10-07; metadata checked with Crossref.
- Supports: observer-based wind estimates suffer from estimation phase delay and convergence error; onboard wind
  measurement is contaminated by the propellers (Sec. I); ground lidar preview + transport model + trim-based
  feed-forward (Secs. II-III); simulation with measured wind: RMS position error 0.698 m without feed-forward, -43.20 %
  with anemometer feed-forward, -46.40 % with lidar preview (Table I); feed-forward robust to multiplicative
  uncertainty and delays in its channel (Tables II-III); feed-forward not flight-tested (Sec. IV-D, V).
- Use for: measured / previewed wind fed forward lowers multirotor position error; phase delay of observer estimates.

### sun2025 - Sun, Wang, Sanalitro, Franchi, Tognon, Alonso-Mora, Science Robotics 10 (2025) eadu8015
- Version read: arXiv:2501.18802v2 (30 Oct 2025), 2026-10-07; publication checked with Crossref.
- Supports: cooperative transport of a cable-suspended load by several quadrotors; onboard controllers estimate the
  external force (cable tension, drag, wind) from the accelerometer and compensate it, INDI inner loop (Methods);
  load drag modelled as quadratic (C_D 1.05, 0.05 m^2) in simulation; in a ~5 m/s fan wind the disturbance on the
  load raised the tracking error (RMSE 0.048 -> 0.055 m with three, 0.070 m with four quadrotors) because the planner
  had no aerodynamic model, and integrating a wind-effect model is named as future work (Results, "Robustness against
  wind disturbance").
- Use for: wind on the load as an identified, uncompensated error source; acceleration-based force compensation.

### guo2020 - Guo, Jia, Yu, Guo, Xie, Control Eng. Pract. 102 (2020) 104560
- Version read: published PDF (ScienceDirect), downloaded by the user, 2026-10-07.
- Supports: MOBADC = DO with an exosystem for the payload force (eq. (6), harmonic blocks A_i, (12)) + position ESO for
  the wind (eqs. (14)-(15)) + attitude ESO (eqs. (19)-(20)); position law (9) a_d = K_g e_g + K_v e_v + g e3 + gdd_d,
  F = m a_d - d_mf - d_lf; attitude law (18); attitude dynamics (5) M(eta) etadd + C etad = tau + d, with M, C from
  Raffo et al.; thrust direction (4b); classical PID = (9), (16), (18) without the estimates (Remark 9); Theorem 1
  (bounded error of the position loop if d_lf' is bounded and Xi is Hurwitz, eqs. (22)-(28)) and Theorem 2 (asymptotic
  stability of the attitude loop under a small-angle linearisation, Assumption 4); parameters A.1 (m = 1.121 kg) and
  gains A.2 (K_g diag(12,12,35), K_v diag(8,8,18), K_eta diag(2.16,1.92,0.59), K_omega diag(0.20,0.12,0.12), attitude
  ESO 50/833/3906); indoor tests with fans up to 5 m/s, circle R 0.8 m at 1.26 m/s, payload 500 g; Table 1 (p. 9) Test 4
  mean / STD: classical 0.1502 / 0.0700, ESO 0.2054 / 0.0205, DO 0.0725 / 0.0480, MOBADC 0.0350 / 0.0202 m; STD as the
  within-run standard deviation of the error norm (Sec. 4.3).
- Use for: the baseline, its laws, gains and indoor ranking; what its authors prove about stability.
- Not for: ISS with respect to a compensation error (not in the paper); outdoor wind; delay.

### bobtsov2012 - Bobtsov, Pyrkin, Int. J. Adapt. Control Signal Process. 26 (2012) 302-315
- Version read: published PDF (Wiley), downloaded by the user, 2026-10-07.
- Supports: cancellation of an unknown multiharmonic disturbance for a nonlinear plant with a known constant input
  delay h, output measured only (Sec. 2, Assumptions 1-6); ideal law (13) u = -sum (1/L_i) delta_i(t + h - phi_i/w_i),
  i.e. each estimated harmonic shifted ahead by the delay; realisable predictor (48)-(54) with k_p = cos(h w - phi_u)/L_u,
  k_d = sin(h w - phi_u)/(w L_u) - with L_u = 1, phi_u = 0 this is the rotation e^{A tau} of a harmonic; frequency
  identification (17)-(35); "the well-known controllers that can reject the unknown disturbance do not work when the
  control has delay" (Sec. 1, 7); numerical example and reaction-wheel pendulum experiment.
- Use for: shifting an estimated harmonic across a known delay (the source of C1).
- Not for: exosystem-state propagation in a disturbance observer, the orthogonality bound (both ours).

### qian2020 - Qian, Liu, IEEE Trans. Ind. Electron. 67(3) (2020) 2021-2029
- Version read: accepted manuscript PDF (IEEE), downloaded by the user, 2026-10-07.
- Supports: quadrotor with a cable-suspended point-mass payload; wind and cruising drag on both bodies as linear
  drag on the airspeed, d_c = -lambda_p(v_q + B v_p), d_w = lambda_p v_w (eq. (9)); the lumped constant disturbance W
  estimated by an uncertainty and disturbance estimator (UDE, eqs. (18)-(22)); no wind sensor (Sec. I); reduction
  theorem for cascade stability; simulation only.
- Use for: load drag lumped into one estimated disturbance.

### wang2024 - Wang, Shen, Qiu, Zhu, IET Control Theory Appl. 18 (2024) 1686-1698
- Version read: published PDF (open access), downloaded by the user, 2026-10-07.
- Supports: Lagrangian model of quadrotor + suspended load (eqs. (1)-(6)); wind from the Dryden model (Sec. 2.2);
  generalised wind drag forces on all coordinates as functions of the wind speed (eq. (9); called linear in the text,
  written with squares); adaptive law for the payload mass (13); nonlinear disturbance observers (15)-(16) for the
  translational and attitude wind disturbances; uniform boundedness (Theorem 1); simulation only.
- Use for: wind on the load estimated with the other translational disturbances.
- Not for: "linear drag" (the formula is quadratic in the wind-speed components).

### li2023 - Li, Zhu, ISAS 2023, pp. 1-6
- Version read: published PDF (IEEE Xplore), downloaded by the user, 2026-10-07 (previously abstract only).
- Supports: ESO for system uncertainties and external wind (eq. (5)), NDO for the payload perturbation in the position
  loop (eqs. (7)-(10)); payload model (1) without aerodynamic force on the load; Dryden wind applied to the attitude
  axes; simulation only, compared with PID and ADRC.
- Use for: observers combined for the wind and the load; a slung-load model that neglects the load's drag.

### zhu2025 - Zhu, Zheng, Shao, Huang, Zheng, IEEE Trans. Autom. Sci. Eng. 22 (2025) 6061-6075
- Version read: published PDF (IEEE Xplore), downloaded by the user, 2026-10-07.
- Supports: swing experiments - linear and quadratic air-drag models under-damp small swings (21.8 % / 51 % peak error
  below 0.1 rad), the extra damping comes from cable-joint dry friction and cable elasticity, modelled by a sign term
  (eq. (7), Remark 1, Sec. II-C, Table III); the swing-disturbance spectrum sets the UDE bandwidth (Fig. 4, eqs.
  (23)-(26), (38)-(40)); payload swing and wind lumped into one total disturbance f (eq. (17)); indoor flights with fans.
- Use for: air drag alone damps small swings too weakly; load forces left to a lumped estimator; estimator bandwidth
  from a swing model.

### raffo2010 - Raffo, Ortega, Rubio, Automatica 46 (2010) 29-39
- Version read: published PDF (ScienceDirect), downloaded by the user, 2026-10-07.
- Supports: Lagrange-Euler model; translational dynamics (6)-(7) with thrust along the third column of R; rotational
  dynamics (10) M(eta) etadd + C(eta, etad) etad = tau with the full Euler-angle inertia (11) and Coriolis terms;
  integral MPC + nonlinear H-infinity control; simulation only.
- Use for: the attitude model inherited by Guo et al.

### han2009 - Han, IEEE Trans. Ind. Electron. 56(3) (2009) 900-906
- Version read: published PDF (IEEE Xplore), downloaded by the user, 2026-10-07.
- Supports: ADRC - the total disturbance F(t) as an extended state estimated by the ESO (eqs. (19)-(22)) and rejected
  by the control law (25)-(26); plant delay handled by approximation, predictive output feedback (Smith predictor) or a
  predictive pseudo input (Sec. V-A).
- Use for: lumped-disturbance estimation and rejection; prediction as a remedy for a known delay.

### omar2023 - Omar, Akram, Mukras, Mahvouz, Alexandria Eng. J. 63 (2023) 253-270
- Version read: published PDF (open access), downloaded by the user, 2026-10-07.
- Supports: survey - swing-free trajectories without payload feedback (Sec. 2.3.1, including dynamic programming and
  reinforcement learning) and anti-swing controllers with swing-angle feedback (Sec. 2.3.2); most results in
  simulation, few hardware implementations (Sec. 3.1, Table 1).
- Use for: overview of slung-load swing control.

### palunko2012 - Palunko, Cruz, Fierro, IEEE Robot. Autom. Mag. 19(3) (2012) 69-79
- Version read: published PDF (IEEE Xplore), downloaded by the user, 2026-10-07.
- Supports: swing-free trajectory generation by dynamic programming (eqs. (11)-(17)) with indoor experiments (47 g load,
  0.62 m link); adaptive control for a shifted centre of gravity.
- Use for: trajectory shaping against swing.

### notter2016 - Notter, Heckmann, McFadyen, Gonzalez, IFAC-PapersOnLine 49-17 (2016) 182-187
- Version read: published PDF (ScienceDirect), downloaded by the user, 2026-10-07.
- Supports: coupled multirotor + heavy slung load model with quadratic load drag f_D,L = -1/2 C_D rho A |v_L| v_L
  (eq. (12)); MPC that actively damps the load while tracking a figure-eight, flight-tested indoors; "the authors
  ascribe [the larger lag of the load] to undervaluing the aerodynamic drag force of the load in the prediction model"
  (Sec. 5.2).
- Use for: model-predictive swing damping in flight; evidence that the load's drag matters.

### faust2017 - Faust, Palunko, Cruz, Fierro, Tapia, Artificial Intelligence 247 (2017) 381-398
- Version read: journal pre-proof PDF (ScienceDirect, "Prn:6/01/2015", 18 pp.), downloaded by the user, 2026-10-07.
- Supports: reinforcement learning (approximate value iteration) of swing-free / minimal-residual-oscillation
  trajectories, path following and PRM planning; experiments with a quadrotor and a suspended load (Sec. 3-4).
- Use for: learning approaches to swing-free transport.

### gomiero2026 - Gomiero, von Ellenrieder, IEEE Trans. Autom. Sci. Eng. 23 (2026) 3065-3082
- Version read: published PDF (IEEE Xplore), downloaded by the user, 2026-10-07 (previously abstract only).
- Supports: Lagrangian matrix model of a heavy-lift quadrotor with a rigid cuboid payload (eqs. (8)-(26)); quadratic
  drag on the relative velocity of both bodies (eqs. (30)-(32)); wind as mean shear + Dryden turbulence + gusts
  (eqs. (34)-(36)); first-order and super-twisting sliding-mode control, disturbances rejected by robustness, no
  estimate (Sec. III-IV); simulation only (72 kg vehicle, 25 kg load, 18 m cable); observers named as future work.
- Use for: load drag modelled in full and left to the robustness of the feedback law.

## TO GET (cited in the manuscript, full text not yet read - the user downloads into refs/<key>.pdf)

| key | why it is cited | status |
|---|---|---|

(none - 2026-10-07: the thirteen works were downloaded and read; hamilton2019 was dropped)

## DROP

### shi2019 - Shi et al., ICRA 2019 (Neural Lander)
- Version read: arXiv:1811.08027v2, 2026-10-07. Learned ground-effect residual for landing; no wind, no slung load -
  not needed for any statement of the paper (wind learning is covered by oconnell2022).

### hamilton2019 - Hamilton, Debnath, NREL technical report NREL/TP-5000-72091 (2019)
- Not obtained (OSTI unreachable from this machine); dropped by the user on 2026-10-07. The manuscript describes the M5
  sonic anemometers (61 and 74 m, 20 Hz) as properties of the public data set it uses, without this citation.
