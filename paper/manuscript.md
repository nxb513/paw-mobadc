---
bibliography: references.bib
csl: elsevier-with-titles.csl
link-citations: true
---

# Prediction-augmented, payload-wind-aware multiple-observer control of a quadrotor with a slung load in measured wind

*Draft for GĐ11d (2026-10-04). Every result number is quoted from `docs/RESULTS_P2.md` or `paper/tables/tables_p2.md`
(both generated from the result files; verbatim, or rounded where allowed; `tools/check_propagation.py`). Every labelled equation has a row in
`docs/EQUATIONS_TABLE.md` (`tools/check_equations.py`). Controller names follow REGISTER_P2 §63.1
(`tools/check_names.py`).*

## Highlights

- PAW-MOBADC: 78 % lower error than MOBADC on held-out circle days; delay step -58 %
- All claims preregistered; confirmed on 14 held-out days of measured wind
- Payload drag in the wind feed-forward: a further 63 % (hover), 37 % (circle)
- Wind foresight: no usable headroom in 12 measured-wind groups at 61-74 m height
- Baseline's published gains: stable at 17 ms, unstable from 25 ms motor lag

## Abstract

A quadrotor carrying a slung load in wind is disturbed by the cable force and by the wind on both bodies. We take
the multiple-observer anti-disturbance controller of Guo et al. (MOBADC) as the baseline and simulate it on a
quadrotor coupled to a spherical pendulum in measured NREL M5 wind, with every claim registered before its data were
opened. The proposed PAW-MOBADC lowers the pooled position error of MOBADC on a circle by 78 % on fourteen held-out
days, at about 15 % higher control effort. Two steps produce this. Compensating the loop delay for the payload
force, by propagating the observer's estimate through its exosystem, gives −58 % against MOBADC with measured-wind
feed-forward. Adding the payload's aerodynamic drag to that feed-forward, derived from the coupled system's force
balance, gives a further 63 % in hover and 37 % on the circle; this step was found on development data and
confirmed on the held-out days. Perfect advance wind knowledge gives no usable headroom in twelve measured-wind
conditions. An INDI-type disturbance estimate is better in hover with an ideal accelerometer, but loses this
advantage with a 0.5° attitude error, and is worse on the periodic circle. The published baseline gains are stable at
17 ms motor lag but diverge from 25 ms (simulation). The method improves the vehicle's position, not payload swing.

**Keywords:** quadrotor; slung load; disturbance observer; delay compensation; wind; preregistration

## Notation

| symbol | meaning |
|---|---|
| $\boldsymbol x_Q, \boldsymbol v_Q$ | position and velocity of the quadrotor (inertial frame, $\boldsymbol e_3$ up) |
| $\boldsymbol q \in S^2$, $\boldsymbol\omega$ | unit cable direction from the quadrotor to the payload, its angular velocity |
| $m_Q, m_L, L$ | quadrotor mass, payload mass ($m_p$ in the tables), cable length |
| $T$ | cable tension |
| $\boldsymbol F_{wQ}, \boldsymbol F_{wL}$ | wind force on the airframe and on the payload |
| $\boldsymbol d_{mf}, \boldsymbol d_{lf}$ | payload and wind disturbance in the translational dynamics, as in [@guo2020] |
| $\tau$, $\tau_{prev}$ | payload-prediction horizon, reference-preview horizon |
| $\hat K$ | assumed payload-to-airframe drag-area ratio |
| $P$ | pooled error $\sqrt{\mathrm{mean}_i\, m_i^2}$ over a set of segments |

## 1. Introduction

### 1.1 Problem

Delivering a load on a cable from a small multirotor, or lowering equipment in a rescue, puts two disturbances on
the vehicle at once: the force the swinging load exerts through the cable, and the force of the wind on the
airframe and on the load itself [@omar2023], [@sreenath2013], [@palunko2012]. Guo et al. [@guo2020] treat both with a multiple-observer
anti-disturbance controller (MOBADC): a disturbance observer (DO) with an internal model of the payload force, an
extended state observer (ESO) for the wind, and an attitude ESO. They validated MOBADC in indoor flight with a real
payload and fan wind of up to 5 m/s on one circle [@guo2020]. Here we extend the study in simulation: the payload is a
three-dimensional pendulum, both bodies feel quadratic drag, motors lag, sensors sample and delay, the wind is
measured outdoor wind, the vehicle flies three planned trajectories and hovers, and the main claims are confirmed on
a held-out set of days.

On this plant two facts shape the problem. The payload force is periodic along a planned trajectory and the
controller acts on it only after the loop delay; and the wind acts on the payload as well as on the airframe,
while the controller's wind channel accounts for the airframe only.

Controllers for a slung load in wind usually estimate the wind force with an observer or estimator [@qian2020], [@wang2024], [@li2023],
and are evaluated on constant winds and gust zones [@qian2020], Dryden turbulence [@wang2024], or a mean shear with turbulence and
discrete gusts [@gomiero2026]. A wind sensor on the vehicle offers the wind force before it acts, but its use then depends
on how much of that force the controller's model accounts for. We therefore ask two questions on measured wind: how
much of the remaining error is due to the loop delay, and how much to the wind on the payload that the controller's
model leaves out. Every claim was registered before the data that test it were opened, and the held-out test uses
fourteen days of wind never used for any controller run or parameter choice.

### 1.2 Contributions

**Headline.** On the circle, the proposed method (PAW-MOBADC) lowers the pooled position error of Guo's MOBADC by 73 %
on the development set and by 78 % on the fourteen held-out days (descriptive comparisons, Section 6.1). The two
steps that produce this gain are:

- **C1 - compensation of the loop delay for the payload force (PA-MOBADC).** The payload force along a planned
  trajectory is periodic, and the controller acts on it one loop delay late. We compensate the delay by propagating
  the DO estimate ahead through its own exosystem - the harmonic time shift of Bobtsov and Pyrkin [@bobtsov2012], applied to the
  DO of [@guo2020]. Registered on the development set and confirmed on the held-out days: −58 % against MOBADC with the
  measured-wind feed-forward (MOBADC-W) on the circle. A reference preview realises the same compensation on planned
  trajectories and gives a comparable gain (−62 %); Section 7.2 compares the two.
- **C2 - payload drag in the wind feed-forward (PAW-MOBADC, the proposed method).** The measured-wind feed-forward
  is scaled by $1 + \hat K$, the share of the wind force that the payload's drag adds in the force balance of the
  coupled system (Section 4.4). The formula follows from that balance; we do not claim it as new. What we report is
  its effect on measured wind: on the held-out days it lowers the error by a further 63 % in hover and 37 % on the
  circle against PA-MOBADC; on the development set by 66 % and 40 %; with $\hat K$ scaled by 0.7 or 1.3 the hover gain
  stays at 56–59 %. **Found post hoc on the development set**, then registered and **confirmed on the held-out days**.
- **What separates the methods.** A payload force that is periodic and fast compared with the loop delay has to be
  predicted; a slow disturbance can be measured fast enough. An INDI-type estimate from the accelerometer (INDI-DE)
  is therefore better than PAW-MOBADC in hover and much worse on the circle, and its advantage in hover rests on an
  ideal accelerometer (Section 6.5).
- **C3 - advance knowledge of the wind does not help**, for the 61–74 m wind of this dataset: a wind oracle that knows
  the true future wind gives no usable headroom in any registered wind group.
- **C4 - the published gains are fragile to motor lag.** In simulation, Guo's gains are stable at a motor lag of
  17 ms and diverge at 25 ms and above.
- **Negative results, reported as such.** A model-based payload predictor (MBP) did not pass its registered test;
  the hover headroom claim of C3's one post-hoc group could not be confirmed (too few held-out segments).

### 1.3 What we do not claim

- The method improves the **position of the vehicle**. It does **not** damp payload swing; the payload's RMS angle is
  essentially unchanged across controllers (Section 7.3). Swing damping is a direction for later work.
- Results hold for **planned trajectories** (circle, figure-eight, square) and hover; nothing is claimed for
  trajectories not known in advance.
- Everything is **simulation**, with a deliberately idealised accelerometer and a noise-free wind sensor
  (Section 8); a wind-sensor noise of 0.1 m/s changes the main results by less than 1.3 percentage points.

### 1.4 Outline

Section 2 reviews related work. Section 3 gives the plant and Section 4 the controllers, including the derivation of
the payload-drag term. Section 5 describes the wind data, the registration and the statistics. Section 6 reports the
results, including the failures of the proposed method and the negative results; Section 7 discusses them and
Section 8 lists the limitations.

In short: the payload force on a planned trajectory is best predicted over the loop delay, the wind on the payload is
best added to the measured-wind feed-forward, and a slow disturbance can instead be measured - provided the
accelerometer is good.

## 2. Related work

**Slung-load control.** Geometric models and controllers for a quadrotor with a cable-suspended load are given by
Sreenath, Lee and Kumar [@sreenath2013]; surveys collect the trajectory-shaping, swing-damping and learning approaches [@omar2023], [@palunko2012],
[@notter2016], [@faust2017]. Wind on the payload has been modelled as linear drag and lumped, with the cruising drag, into one
disturbance estimated without a wind sensor [@qian2020], [@wang2024]; air drag alone under-damps small swings, and the missing damping
(cable-joint friction, cable elasticity) has been identified in flight [@zhu2025]. Harmonic observers estimate the periodic
slung-load disturbance [@shi2018]. Gomiero and von Ellenrieder [@gomiero2026] model a heavy-lift quadrotor and a rigid cuboid
payload in wind by Lagrangian mechanics, with aerodynamic drag and propeller gyroscopic effects, and control it by
sliding modes; Li and Zhu [@li2023] use an ESO for the wind and system uncertainty and a nonlinear disturbance observer for
the payload. Our plant uses the model of [@sreenath2013] with drag and cable damping added (Section 3); C2 uses a
measured wind instead of an estimated lumped term.

**Disturbance observers and ADRC.** DO-based control [@chen2016], [@chen2004] and active disturbance rejection with an ESO [@han2009], [@gao2003],
[@guobz2011] are the foundations of MOBADC [@guo2020]. The DO's internal model follows the internal-model principle [@francis1976], [@isidori1990];
adaptive internal models remove the need to know the frequency [@serrani2001], [@nikiforov1998], [@bodson1997], [@marino2003], [@bobtsov2012].

**Delay and preview.** Compensating input delay by prediction is classical [@artstein1982], [@richard2003], [@krstic2009]; preview of a known reference
improves tracking [@tomizuka1975], [@birla2015]. Bobtsov and Pyrkin [@bobtsov2012] cancel a multiharmonic disturbance across a known input delay by
shifting each estimated harmonic ahead by the delay (their (47)–(54)). C1 uses the same shift, written on the state
of the DO's exosystem: the frequencies are those of [@guo2020], so no frequency is identified; the DC mode is not shifted; and
the horizon is the measured closed-loop lag, not a known input delay.

**Wind and learned models.** Learned and estimated aerodynamic models improve multirotor flight in wind [@byun2021], [@oconnell2022],
[@shi2019]. INDI estimates the disturbance from measured acceleration [@smeur2018], [@smeur2016]; we use its outer loop as the
comparison method INDI-DE.

## 3. Model

The plant used in every result, **P2**, couples a rigid quadrotor to a **three-dimensional spherical pendulum**
(the payload on a rigid, massless cable). The equations are integrated with a fixed step of 1 ms; every source
and value is listed in Table 1 and `docs/EQUATIONS_TABLE.md`.

### 3.1 Quadrotor and spherical pendulum

With the cable taut, the quadrotor and the payload obey

$$m_Q\dot{\boldsymbol v}_Q = \boldsymbol F - m_Q g\boldsymbol e_3 + T\boldsymbol q + \boldsymbol F_{wQ} - \boldsymbol F_d$$ {#eq:p2-quad}

$$m_L\ddot{\boldsymbol x}_L = -m_L g\boldsymbol e_3 - T\boldsymbol q + \boldsymbol F_{wL} + \boldsymbol F_d,\qquad \boldsymbol x_L = \boldsymbol x_Q + L\boldsymbol q$$ {#eq:p2-load}

with the cable direction on the sphere

$$\dot{\boldsymbol q} = \boldsymbol\omega\times\boldsymbol q,\qquad \dot{\boldsymbol\omega} = \tfrac{1}{L}\,\boldsymbol q\times\Big[\frac{\boldsymbol F_{wL}+\boldsymbol F_d}{m_L} - \frac{\boldsymbol F + \boldsymbol F_{wQ} - \boldsymbol F_d}{m_Q}\Big]$$ {#eq:p2-sphere}

and the tension that keeps the cable length fixed,

$$T = \mu\Big[\frac{\boldsymbol q\cdot\boldsymbol F_{wL}}{m_L} - \frac{\boldsymbol q\cdot(\boldsymbol F + \boldsymbol F_{wQ})}{m_Q} + L\lVert\dot{\boldsymbol q}\rVert^2\Big],\qquad \mu = \frac{m_Q m_L}{m_Q + m_L}.$$ {#eq:p2-tension}

Without wind and damping these reduce exactly to the model of [@sreenath2013]. A cable that goes slack ($T \le 0$) is flagged and
its segment leaves the evaluation; no slack dynamics are simulated. Air drag alone under-damps small swings [@zhu2025],
so the cable damping is added as an internal force on both bodies,

$$\boldsymbol F_d = -c\,L\,(\boldsymbol\omega\times\boldsymbol q),\qquad c = 2\zeta_s\omega_n m_L,\qquad \omega_n = \sqrt{g/L}.$$ {#eq:p2-damp}

The coefficient is the viscous damping of a linear oscillator written with its damping ratio [@rao2010, chap. 2]; we choose
$\zeta_s = 0.05$.

The attitude dynamics are those of [@guo2020], taken from [@raffo2010], with full Euler-angle inertia and Coriolis terms, and the
thrust direction follows the attitude:

$$\boldsymbol M(\boldsymbol\eta)\ddot{\boldsymbol\eta} + \boldsymbol C(\boldsymbol\eta,\dot{\boldsymbol\eta})\dot{\boldsymbol\eta} = \boldsymbol\tau,\qquad \boldsymbol F = f\,\boldsymbol R(\boldsymbol\eta)\boldsymbol e_3.$$ {#eq:rot}

### 3.2 Wind and the two disturbance paths

Both bodies feel quadratic drag on the velocity relative to the air [@anderson2010, chap. 1],

$$\boldsymbol F_w = \tfrac12\rho\,(C_DA)\,\lVert\boldsymbol w - \boldsymbol v\rVert(\boldsymbol w - \boldsymbol v),$$ {#eq:drag}

and we choose the airframe's drag area so that it feels 1.0 N in a 5 m/s wind, with the payload's drag area a
fraction $K$ of it:

$$\tfrac12\rho(C_DA)_Q = K_w/U_{ref},\qquad (C_DA)_L = K\,(C_DA)_Q.$$ {#eq:drag-cal}

The disturbances of the controller's model [@guo2020] are then the cable force and the wind on the airframe,

$$\boldsymbol d_{mf} = T\boldsymbol q - \boldsymbol F_d,\qquad \boldsymbol d_{lf} = \boldsymbol F_{wQ}.$$ {#eq:dist-map}

The wind on the payload does not appear in $\boldsymbol d_{lf}$; it reaches the vehicle only through the cable. That is
the gap C2 closes.

### 3.3 Actuators and sensors

Each motor is a first-order lag [@ogata2010, chap. 5],

$$\dot f_i = (f_{i,cmd} - f_i)/\tau_m,\qquad \tau_m = 17\ \mathrm{ms},$$ {#eq:motor}

behind the allocation of [@guo2020] with rotor-force and torque saturation:

$$[f;\boldsymbol\tau] = \boldsymbol\Gamma[f_1;\dots;f_4],\qquad f_i = \mathrm{sat}_{[0,f_{\max}]}\big(\boldsymbol\Gamma^{-1}[f;\mathrm{sat}(\boldsymbol\tau)]\big).$$ {#eq:alloc}

The attitude reference inverts the force direction with a 30° tilt clamp and a total-thrust limit (Table 1). The
position loop runs at 125 Hz on motion-capture positions with 8 ms delay; the attitude loop at 1 kHz; the wind
sensor samples at 20 Hz with one sample of delay (zero-order hold [@astrom2011, chap. 2]):

$$\boldsymbol w_s(t_k) = \boldsymbol w(t_k - 0.05\ \mathrm{s}),\qquad \boldsymbol a_{meas} = \boldsymbol a_Q + \boldsymbol n_a.$$ {#eq:sensors}

The accelerometer measures the inertial acceleration plus noise, not the specific force in the body frame; this
idealisation favours the acceleration-based comparison method (Section 8).

## 4. Controllers

### 4.0 What is inherited and what is added

Everything this work adds to the simulation model `baseline1.slx` is inserted by a named `build_*.m` script, and
nothing else in the model is; a gate checks that every such script appears below. **Inherited from [@guo2020], unchanged:**
the rigid-body model, the attitude and position laws with every gain, the position and attitude ESOs, the DO with its
one-harmonic exosystem, and the composition of (@eq:guo-law); MOBADC is this, with nothing added.

| component | inserted by | used in this paper |
|---|---|---|
| plant P2 (spherical pendulum, quadratic drag, motor lag, sensors, discrete loops), the controller's quadratic wind model with its $(1+\hat K)$ scale, the INDI-DE and MBP blocks, the wind-to-payload term of C3 and the known-weight trim | `build_p2_plant` | yes - Sections 3, 4.2–4.5 |
| DC mode of the DO's internal model | `build_do_matrices` | yes - MOBADC-DC and every variant after it |
| payload predictor $\boldsymbol B e^{\boldsymbol A\tau}\hat{\boldsymbol\xi}$ | `build_payload_predictor` | yes - C1 |
| measured-wind path into $\hat{\boldsymbol d}_{lf}$ (made quadratic through `build_p2_plant`) | `build_pa_mobadc` | yes - MOBADC-W |
| reference preview $\ddot{\boldsymbol\gamma}_d(t+\tau_{prev})$ | `build_traj_preview` | yes - MOBADC-W + preview |
| trajectory shapes (hover, circle, figure-eight, square, multi-sine) | `build_traj5` | yes |
| measured wind series | `build_wind_series` | yes |
| frozen learned wind predictor (PI-MoE) | `build_wind_predictor` | C3 only |
| wind-sensor noise injection | `build_wind_sensor_noise` | off in every reported run |
| inactive blocks kept from an earlier version of the model, switched off in every run | `build_payload_pendulum`, `build_payload_wind`, `build_payload_inject`, `build_im_est_online` | no |
| probes on the wind estimate and on the vehicle acceleration | `build_dlf_probe`, `build_nu_dot_log` | instrumentation only |
| tilt, thrust, rotor and torque limits | `thrust_attitude_ref`, `motor_allocation` | yes - Section 3.3 |

### 4.1 The baseline and its variants

The position law of [@guo2020] is

$$\boldsymbol a_d = \boldsymbol K_\gamma\boldsymbol e_\gamma + \boldsymbol K_v\boldsymbol e_v + g\boldsymbol e_3 + \ddot{\boldsymbol\gamma}_d,\qquad \boldsymbol F = m\boldsymbol a_d - \hat{\boldsymbol d}_{mf} - \hat{\boldsymbol d}_{lf},$$ {#eq:guo-law}

with Guo's gains (Table 1). $\hat{\boldsymbol d}_{mf}$ comes from the DO with the exosystem

$$\dot{\boldsymbol\xi} = \boldsymbol A\boldsymbol\xi,\qquad \boldsymbol d_m = \boldsymbol B\boldsymbol\xi,\qquad \boldsymbol A_i = \begin{bmatrix}0&\sigma_i\\-\sigma_i&0\end{bmatrix},$$ {#eq:exo}

and $\hat{\boldsymbol d}_{lf}$ from the position ESO. The controllers compared are:

| name | definition |
|---|---|
| **PID** | Guo's laws with every estimate switched off |
| **DO**, **ESO** | Guo's controller with only the DO, or only the two ESOs |
| **MOBADC** | Guo's controller as published [@guo2020] |
| **MOBADC-DC** | MOBADC with a constant (DC) mode added to the DO's internal model |
| **MOBADC-W** | MOBADC-DC with the measured-wind feed-forward replacing the position ESO (Section 4.2) |
| **MOBADC-W + preview** | MOBADC-W with the reference acceleration taken $\tau_{prev}$ ahead |
| **PA-MOBADC** | MOBADC-W with the DO estimate predicted $\tau$ ahead (C1) |
| **PAW-MOBADC** | PA-MOBADC with the payload's drag in the wind feed-forward (C2) - **the proposed method** |
| **INDI-DE** | the comparison method: INDI-type acceleration-based disturbance estimation (Section 4.5) |

PID and DO are also run with the known payload weight added to the DO estimate ("+ trim").

### 4.2 Measured-wind feed-forward

MOBADC-W replaces the slow position ESO by the controller's drag model fed with the measured wind,

$$\hat{\boldsymbol d}_{lf} = \frac{K_w}{U_{ref}}\lVert\boldsymbol w_s - \boldsymbol v_Q\rVert(\boldsymbol w_s - \boldsymbol v_Q).$$ {#eq:wind-ff}

### 4.3 C1 - compensation of the loop delay (PA-MOBADC)

The payload force along a planned trajectory is periodic, the controller acts on it one loop delay late, and the
DO's exosystem knows its frequency. The delay is therefore compensated by propagating the estimate over the
closed-loop delay through the exosystem itself:

$$\hat{\boldsymbol d}_{mf}(t+\tau) = \boldsymbol B\,e^{\boldsymbol A\tau}\hat{\boldsymbol\xi}(t).$$ {#eq:pred}

Each $2\times2$ block of $e^{\boldsymbol A\tau}$ is a rotation, so the prediction costs two trigonometric evaluations per
mode. For a harmonic mode this is the predictor of [@bobtsov2012] (their (52)–(54)) with unit gain and no plant phase, since the
payload force enters the force channel directly. The horizon was measured on the development set by a registered
sweep (Fig. 5): $\tau = 290$ ms on the circle; in hover the minimum lies at the floor, $\tau = 0$.

### 4.4 C2 - payload drag in the wind feed-forward (PAW-MOBADC, the proposed method)

The feed-forward of Section 4.2 accounts for the wind on the airframe only. Adding @eq:p2-quad and @eq:p2-load (the
model of [@sreenath2013]) removes the tension and the cable damping, which are internal forces of the two-body system [@goldstein2002, chap. 1]:

$$m_Q\dot{\boldsymbol v}_Q + m_L\ddot{\boldsymbol x}_L = \boldsymbol F - (m_Q+m_L)g\boldsymbol e_3 + \boldsymbol F_{wQ} + \boldsymbol F_{wL}.$$

The payload's drag area is $K$ times the airframe's (@eq:drag-cal). When the payload moves with the vehicle
($\boldsymbol v_L \approx \boldsymbol v_Q$, steady swing) and meets the same wind, @eq:drag gives
$\boldsymbol F_{wL} \approx K\boldsymbol F_{wQ}$, so the wind force the thrust must balance is $(1+K)\boldsymbol F_{wQ}$.
The controller uses its assumed ratio $\hat K$ in place of $K$ and scales the same term:

$$\hat{\boldsymbol d}_{lf} = (1+\hat K)\,\frac{K_w}{U_{ref}}\lVert\boldsymbol w_s - \boldsymbol v_Q\rVert(\boldsymbol w_s - \boldsymbol v_Q),\qquad \hat K = 0.5.$$ {#eq:paw-ff}

Here $\hat K$ equals the simulated $K = 0.5$; Section 6.3 reports $\hat K$ scaled by 0.7 and 1.3. The term is static: it
pushes against the mean wind force that reaches the vehicle through the cable, and it neglects the swing velocity
$\boldsymbol v_L - \boldsymbol v_Q = L\,\boldsymbol\omega\times\boldsymbol q$ and the pendulum dynamics. The formula follows
from the force balance and is not claimed as new. Section 6.4 shows what the term costs on wind records with sensor
spikes.

### 4.5 Comparison and analysis methods

**INDI-DE** estimates the total disturbance from the measured acceleration, as the outer loop of incremental
nonlinear dynamic inversion [@smeur2018]:

$$\hat{\boldsymbol d}_{mf} = H(z)\big[m\boldsymbol a_{meas} - \hat{\boldsymbol F}_{thr} + mg\boldsymbol e_3\big],\qquad \hat{\boldsymbol d}_{lf} = 0,$$ {#eq:h3}

with $H$ a second-order low-pass filter (cut-off 32 Hz, the best value tried, chosen in favour of the competitor) and
the thrust estimated through the nominal motor lag. Guo's attitude loop is kept; there is no inner INDI loop.

**MBP** (model-based payload predictor) replaces the static term of C2 by an open-loop pendulum prediction of the
payload force; it is reported as a negative result.

**Oracle.** For C3, we define a wind channel fed with the true future wind,

$$\hat{\boldsymbol d}_{lf} = \frac{K_w}{U_{ref}}\lVert\boldsymbol w(t+\tau_w) - \boldsymbol v_Q\rVert(\boldsymbol w(t+\tau_w) - \boldsymbol v_Q),$$ {#eq:oracle}

an upper bound on what any wind predictor could give through the controller's force model.

## 5. Experimental design

### 5.1 Wind data and segments

Measured wind comes from the NREL National Wind Technology Center M5 tower [@hamilton2019], [@kaimal1972] at 20 Hz. Each run lasts 200 s;
statistics use $t \ge 140$ s. A segment is admitted to a trajectory's set only if the vehicle could hold position
against the static wind force at the segment's mean wind speed with the trajectory's acceleration (tilt and thrust
within 80 % of their limits); on the circle this admits mean winds up to 8.02 m/s (Fig. 2).

- **Development pool:** 471 segments from 46 days (Fig. 2). Every tuning, every post-hoc finding and every
  development-set number comes from it.
- **Held-out set CONFIRM2:** 14 days chosen by a hash rule before download, opened once after every claim and the
  runner were frozen. Two further days of the manifest had been inspected segment by segment when the wind
  pipeline was built and were excluded before any controller run (deviation D23).

### 5.2 Metric and statistics

The metric of a segment is the mean position-error norm over the window,

$$m_i = \operatorname{mean}_{t\ge140}\lVert\boldsymbol\gamma_d - \boldsymbol\gamma\rVert,$$ {#eq:metric}

pooled over a set as

$$P = \sqrt{\operatorname{mean}_i m_i^2},\qquad \Delta = P_a/P_b - 1,\qquad h = 1 - P_b/P_a.$$ {#eq:pool}

Every ratio carries a paired delete-one-day jackknife standard error ([@efron1993], (11.5), p. 141, with days in place of
observations),

$$\mathrm{SE} = \sqrt{\tfrac{D-1}{D}\textstyle\sum_{d=1}^{D}(\hat\theta_{(-d)} - \bar\theta)^2},$$ {#eq:jack}

the range of leave-one-segment-out values and the median of the per-day values. One table is scored on one set of
segments: a segment on which any column fails leaves that table. Two descriptive quantities are reported beside the
metric, over the same window: the control effort, as the RMS oscillation of the commanded rotor forces about their
own means, and the payload's RMS cable angle.

### 5.3 Registration

Each claim was written, with its test and threshold, in a dated register before its data were opened
(`docs/REGISTER_P2.md`) [@nosek2018], [@munafo2017], [@chambers2013]. Post-hoc findings are labelled as such. The held-out claims are:

- **D2** (C1): $\Delta$ = PA-MOBADC / MOBADC-W − 1 on the circle; confirmed if $\Delta \le -15$ % and
  $\Delta$ + 1.65 SE < 0.
- **H-static** and **H-static-circle** (C2): $h$ = 1 − PAW-MOBADC / PA-MOBADC, in hover and on the circle, scored on
  the segments where PA-MOBADC is not at its tilt clamp; confirmed if the per-day median is at least 10 %,
  $h$ − 1.65 SE > 0, and PAW-MOBADC fails on at most one segment where PA-MOBADC runs.
- **H-hover** (C3, one post-hoc group): $h$ = 1 − oracle / PA-MOBADC in strong-relative hover wind.

Every registered test with a pass/fail outcome is reported as it stands. 2 of the 7 registered predictions scored in
this paper were missed: the C3 headroom gate (no group had headroom) and the acceptance of MBP.

| where | scored | missed |
|---|---|---|
| development gates: D2 gate, C3 headroom gate, MBP acceptance, eligibility of PAW-MOBADC for CONFIRM2 | 4 | 2 |
| CONFIRM2 claims: D2, H-static, H-static-circle (H-hover not scorable: one segment) | 3 | 0 |


## 6. Results

### 6.1 Main comparison

**The proposed PAW-MOBADC lowers the pooled error of MOBADC on the circle from 0.0451 m to 0.0120 m, by 73.42 %
(SE 6.34), on the development set (133 segments on 42 days).** On the 56 held-out CONFIRM2 segments of the circle it
lowers it from 0.0405 m to 0.00873 m, by 78.44 % (SE 0.61), and by 78.82 % on the segments where PA-MOBADC is below
its tilt clamp. Both comparisons are descriptive; the registered claims are the two steps of Sections 6.2 and 6.3.

Table 5 compares six controllers, and PID and DO with a known-weight trim, on the 134-segment development set of the
circle (one set of 133 segments: one segment is left out because PAW-MOBADC stopped on it, Section 6.4). PID tracks
with a pooled error of 0.201 m, DO 0.184 m, ESO 0.0758 m and MOBADC 0.0451 m; the trims lower PID and DO to 0.153 m
and 0.140 m, and INDI-DE reaches 0.0384 m. MOBADC has the lowest error of Guo's four controllers, as in [@guo2020]; the order
of the other three differs from Guo's indoor test, in which ESO was worse than PID. We offer a hypothesis, not
tested here: indoor fan wind varies with position, so the vehicle meets the same gust once per lap, whereas measured
outdoor wind varies slowly in time, which favours the ESO's slowly varying estimate. Fig. 9 shows the six trajectories
on one segment chosen by a registered rule: PAW-MOBADC stays on the desired circle, INDI-DE flies a circle offset
outwards, and the baselines drift with the wind. The pooled within-segment standard deviation is dominated by the few
segments at the tilt clamp, which Table 5 lists; its per-segment medians are given beside it.

### 6.2 C1 - compensation of the loop delay

On the development set the registered gate D2 passed: PA-MOBADC lowered the pooled error of MOBADC-W by 50.33 %
(SE 8.28, by-day median −62.23 %), from 0.0363 m to 0.0180 m. **On CONFIRM2 D2 was confirmed:** −58.30 %
(SE 4.57, leave-one-out range [−60.66, −58.12], by-day median −63.88 %), from 0.0343 m to 0.0143 m (Table 3, Fig. 4).

The gain holds on the other planned trajectories of the development set: −45.41 % on the figure-eight and −24.80 % on
the square. Across every payload mass, cable length and their 2 × 2 corners, the change lies between −58.9 % and
−34.9 % (Table 4). The reference preview (MOBADC-W + preview) compensates the same loop delay along the planned
trajectory and gives a comparable gain, −62.40 % on CONFIRM2; Section 7.2 compares the two realisations.

### 6.3 C2 - payload drag in the wind feed-forward

**Found post hoc on the development set.** PAW-MOBADC was a comparison column of another test (the MBP of Section
6.6). In hover (development set N6_hover, segments where PA-MOBADC is below its tilt clamp) it lowered the error of
PA-MOBADC by 65.68 % (SE 1.59); on the full set the value was +20.27 % (SE 42.39), pulled down by a few segments at
the actuator limit (Table 6). On the circle (development set S40, same subset) it lowered the error by 40.12 %
(SE 2.18). With $\hat K$ scaled by 0.7 and 1.3 (development set S40 hover) the gain stayed at 55.81 % and 59.00 %.

**Registered and confirmed on CONFIRM2.** Both claims were registered from these numbers before CONFIRM2 was opened,
on the segments where PA-MOBADC is below its tilt clamp. H-static (hover) was confirmed with $h$ = +63.00 % (SE 1.37,
52 segments on 14 days, no failure), H-static-circle with +37.18 % (SE 3.04, 53 segments, no failure). On the full
CONFIRM2 sets the error falls from 0.0143 m to 0.00873 m on the circle and from 0.0106 m to 0.00385 m in hover.

**Ablation.** Table 6 separates the two steps. On the held-out circle (full set), C1 gives −58.30 % against MOBADC-W
and C2 a further −39.00 %, a total of −74.57 %. In hover the registered horizon is $\tau = 0$ (Section 4.3), so
PA-MOBADC is identical to MOBADC-W there and the whole gain over MOBADC-W is C2's.

### 6.4 Failures of the proposed method

PAW-MOBADC stopped the solver on **1 of 134 development segments of the circle** (`wind_expl_t150_i0290`) and on
**1 of 139 development segments in hover** (`wind_expl_t150_i0326`), and on **none of the CONFIRM2 segments** (circle
and hover). On the same segments the other controllers ran to the end: on the circle segment PA-MOBADC reached
0.0113 m, INDI-DE 0.0370 m and MOBADC 0.0329 m; on the hover segment PA-MOBADC reached 0.0208 m and INDI-DE 0.0046 m
(MOBADC was run on the circle only). Both segments carry single-sample spikes in the wind record. The static term
multiplies the measured airframe wind force by 1.5, so a spike reaches the force command amplified; a spike filter on
the wind sensor is the remedy we recommend (Section 8).

### 6.5 Comparison with INDI-DE

The two kinds of disturbance separate the methods. **On the circle** (CONFIRM2), the payload force is periodic and
fast compared with the loop delay, and prediction wins: INDI-DE's pooled error is 37.2 mm, against 14.3 mm for
PA-MOBADC and 8.73 mm for PAW-MOBADC (INDI-DE is 159.54 % above PA-MOBADC; 112.93 % on the development set). INDI-DE's
error is nearly the same on every circle segment whatever the wind: it measures the trajectory-driven payload force
one loop delay late. **In hover** (CONFIRM2), the disturbance is slow and fast measurement is enough: INDI-DE reaches
2.60 mm, against 3.85 mm for PAW-MOBADC and 10.6 mm for PA-MOBADC. This advantage rests on an idealised
accelerometer. A horizontal accelerometer bias of 0.086 m/s² or 0.17 m/s² - what an attitude error of 0.50° or 0.99°
leaves in the measured acceleration - raises INDI-DE's error to 7.66 mm and 14.5 mm, above PAW-MOBADC.

### 6.6 Negative results

**C3 - advance wind knowledge.** In the registered headroom test the oracle, which knows the true future wind, lowered
the error of PA-MOBADC by 0.69 % on the circle and by 2.87 % in hover with the wind-to-payload term (Fig. 8). The
largest headroom among the eleven evaluable groups was 5.83 % (a post-hoc group), below the registered threshold of
10 %; no group met the headroom rule. On the unsaturated segments of one post-hoc group, strong-relative wind in hover,
the oracle gained +41.52 % (10 development segments); on CONFIRM2 that wind band held a single usable segment, so
H-hover was **not confirmable**.

**MBP.** The model-based payload predictor did not pass its registered test: in hover it was worse than PA-MOBADC on
the full set (h = −158.83 %, SE 200.46), although better on the unsaturated segments (+72.72 %), and on the circle its
error was 222.33 % above PA-MOBADC. It is not part of the proposed method.

### 6.7 C4 - motor lag and the published gains

With Guo's gains [@guo2020] the full plant stayed stable on all ten registered runs at a motor lag of 17 ms and diverged on
all ten at 25 ms and at 30 ms. Guo et al. flew these gains stably [@guo2020]; a motor lag of 17 ms is consistent with that,
and it is used throughout. This is a simulation result: users of these gains on motors slower than about 25 ms may
expect the loop to diverge.

### 6.8 Control effort and payload swing

On CONFIRM2 (descriptive), the proposed method uses more control effort. The RMS oscillation of the rotor
forces is 0.611 N for PAW-MOBADC on the circle, against 0.532 N for MOBADC, 0.579 N for PA-MOBADC and 0.543 N for
INDI-DE; in hover it is 0.556 N, against 0.532 N for PA-MOBADC and 0.503 N for INDI-DE. On the circle PAW-MOBADC thus
uses about 15 % more control effort than MOBADC (0.611 N against 0.532 N) and in exchange lowers the position error by
78.44 % (Section 6.1). The payload's RMS angle is
almost the same for every controller: 16.24–16.88° on the circle, where it is mostly the steady cone angle of about
15°, and 7.99–8.03° in hover. The swing about the cone angle was not stored.

## 7. Discussion

### 7.1 Prediction or fast measurement

The circle and hover results agree with one rule: a disturbance that is periodic and fast compared with the loop delay
must be predicted; a slow one can be measured. Prediction uses knowledge the controller already has - the exosystem's
frequency - and costs two trigonometric evaluations per mode. Measurement, as in INDI-DE, is free of models but
arrives one delay late and depends on the accelerometer's quality: its advantage in hover disappears with an attitude
error of half a degree (Section 6.5).

### 7.2 Loop-delay compensation: prediction or reference preview

C1 compensates the loop delay for the payload force. On a planned trajectory two realisations do this: propagating
the DO estimate through its exosystem (PA-MOBADC), and feeding forward the reference acceleration one horizon ahead
(MOBADC-W + preview). On CONFIRM2 they give −58.30 % and −62.40 % against MOBADC-W, on the development set −50.33 %
and −53.95 %; in both cases the two values differ by less than the standard error of either. Both need knowledge in
advance - the exosystem needs the frequency of the payload force, the preview needs the future trajectory - so
neither carries over to trajectories that are not planned. PAW-MOBADC uses prediction because it works inside the
observer with the frequency the DO already holds, and leaves the reference and the trajectory generator of [@guo2020]
unchanged. The payload-drag term (C2) is independent of how the delay is compensated; combining C2 with the reference
preview was not tested.

### 7.3 Position, not swing

All controllers leave the payload's RMS angle almost unchanged (Table 5). On the circle that angle is mostly the
steady cone angle the trajectory imposes, not oscillation. The proposed method acts on the vehicle's position: it
removes from the force command what the cable and the wind will push, but it does not try to stop the load swinging.
Damping the swing - by feeding back the cable angle, as in [@sreenath2013] and [@notter2016] - is the natural next step and is outside
the scope of this paper.

### 7.4 Why the wind oracle gives so little

For the 61–74 m wind of this dataset, the wind channel with the measured wind is already close to the oracle: the
sensor delay is one sample, and the static drag model passes the low-frequency wind that dominates the force. Wind
nearer the ground, with more energy at high frequency, may leave more headroom; this was not tested. What remains is the payload's own
dynamics, which C1 and C2 address.

## 8. Limitations

- **Simulation only.** No flight test; the plant, the sensors and the wind interpolation are models.
- **Idealised accelerometer.** It measures inertial acceleration plus noise, with no attitude-induced gravity
  leakage; this favours INDI-DE.
- **Noise-free wind sensor, no rotor-wake effect** on the sensor; a noise of 0.1 m/s changes the main results by less
  than 1.3 percentage points.
- **The payload-drag ratio is known.** $\hat K$ equals the simulated $K$; a ratio scaled by 0.7 and 1.3 was tested in hover
  on the development set only (Section 6.3).
- **Higher control effort.** PAW-MOBADC oscillates the rotor forces more than MOBADC (Section 6.8); actuator wear and
  power were not modelled.
- **C2 with the reference preview** was not tested (Section 7.2).
- **Sensor spikes.** PAW-MOBADC failed on the two development segments with wind spikes (Section 6.4); a real system
  needs a spike filter on the wind sensor.
- **C2 is post hoc on the development set.** It was registered and confirmed on CONFIRM2 only after being found.
- **Prior exposure of the held-out days.** The CONFIRM2 days had entered pooled wind statistics of an earlier stage of
  the project; the two days inspected segment by segment were removed before any controller run (D23).
- **Planned trajectories only**; nothing is claimed for trajectories not known in advance.
- **Point-mass payload on a rigid cable**, attached at the centre of mass; no slack dynamics, no vertical wind, no wind
  moment.
- **No swing damping** (Section 7.3).
- **H-hover was not confirmable** for lack of held-out data in its wind band.

## 9. Conclusion

On a quadrotor with a slung load in measured wind, the proposed PAW-MOBADC lowers the pooled position error of the
multiple-observer controller of Guo et al. on the circle by 78 % on fourteen held-out days (73 % on the development
set), at about 15 % higher control effort. Compensating the loop delay for the periodic payload force gives −58 %,
and adding the payload's aerodynamic drag to the measured-wind feed-forward a further 63 % in hover and 37 % on the
circle. Both steps were registered and confirmed on the held-out days; the second was found post hoc on the
development data.

**For practitioners.**

1. Compensate the loop delay for a periodic payload force. On a planned trajectory, predicting the observer's
   estimate through its exosystem and previewing the reference are equivalent (−58 % and −62 % on the held-out days).
2. Put the payload's drag into the wind feed-forward. A drag-area ratio of 0.7 or 1.3 times the true one keeps most
   of the gain in hover (56 % and 59 % instead of 68 %, development set).
3. Expect little from predicting the wind at 61–74 m height: perfect foresight gained at most 6 % in any wind group.
4. Use an INDI-type acceleration-based estimate for slow disturbances in hover only if the attitude error is well
   below 0.5°.
5. Check published gains against the motor lag of the platform: the baseline gains are stable at 17 ms and diverge
   from 25 ms.

**Limitations and next steps.** All results come from simulation; hardware-in-the-loop tests and flights are the
next step. The method does not damp payload swing, which calls for feedback of the cable angle. The wind was
measured at 61–74 m; wind near the ground, with more energy at high frequency, may change the role of wind
prediction. Only planned trajectories were studied. Two solver stops on wind records with single-sample spikes show
that the wind sensor needs a spike filter before the payload-drag term is used in flight.

## Figure captions

**Fig. 1.** Plant P2 (quadrotor coupled to a three-dimensional spherical pendulum, both under quadratic drag) and the
controller with the compared estimates.

**Fig. 2.** Wind data: mean wind speed and turbulence intensity [@burton2011, chap. 2] per segment, development pool and CONFIRM2, with the
operating envelopes.

**Fig. 3.** One held-out circle segment (chosen by a registered rule): position error and payload angle of MOBADC-W,
PA-MOBADC, PAW-MOBADC and INDI-DE.

**Fig. 4.** C1: PA-MOBADC / MOBADC-W − 1 and the reference preview, per trajectory, development set and CONFIRM2; per
segment comparison.

**Fig. 5.** Pooled error against the prediction horizon, development segments; the chosen horizon is marked.

**Fig. 6.** C2: gain of PAW-MOBADC over PA-MOBADC with ±1.65 SE, development (post hoc) and CONFIRM2 (registered);
control effort and payload angle.

**Fig. 7.** PA-MOBADC, PAW-MOBADC and INDI-DE on the circle and in hover.

**Fig. 8.** C3: headroom of perfect advance wind knowledge in the twelve registered wind groups.

**Fig. 9.** The six controllers of Table 5 on one development circle segment (chosen by a registered rule).

## Data and code availability

Code, registers and generated tables: the project repository (commit hashes in `docs/REGISTER_P2.md`). The wind records
are public (NREL NWTC M5 tower data repository [@hamilton2019]).

## References

::: {#refs}
:::
