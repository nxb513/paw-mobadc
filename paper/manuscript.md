---
bibliography: references.bib
csl: elsevier-with-titles.csl
link-citations: true
---

# Prediction-augmented, payload-wind-aware multiple-observer control of a quadrotor with a slung load in measured wind

## Abstract

A quadrotor carrying a load on a cable in wind is disturbed by the cable force of the swinging load and by the wind
on the airframe and on the load. Observer-based anti-disturbance controllers estimate both and cancel the estimates.
This paper argues that, once the wind is measured, the remaining error is set by two gaps in the controller's model
rather than by the quality of the estimates: the loop delay acts on a payload force that is periodic along a planned
trajectory, and the wind feed-forward omits the drag on the load. Both gaps are closed with knowledge the controller
already holds: the payload estimate is propagated over the loop delay through the observer's own exosystem, and the
measured-wind feed-forward is scaled by the share of the wind force that the force balance of the coupled system
assigns to the load. The resulting controller, PAW-MOBADC, is evaluated in simulation on a quadrotor coupled to a
spherical pendulum in wind measured at the NREL M5 tower, against the multiple-observer controller (MOBADC) of Guo et
al., with every claim registered before its data were opened. On fourteen held-out days the delay compensation lowers
the error of MOBADC with measured-wind feed-forward by 58 %, the payload-drag term lowers it by a further 63 % in
hover and 37 % on a circle, and the complete controller lowers the error of MOBADC on the circle by 78 %. An
acceleration-based estimate does not close the first gap, and perfect advance knowledge of the wind adds at most 6 %.

**Keywords:** quadrotor; slung load; disturbance observer; delay compensation; wind feed-forward; preregistration

## Notation

| symbol | meaning |
|---|---|
| $\boldsymbol x_Q, \boldsymbol v_Q$ | position and velocity of the quadrotor (inertial frame, $\boldsymbol e_3$ up) |
| $\boldsymbol q \in S^2$, $\boldsymbol\omega$ | unit cable direction from the quadrotor to the payload, its angular velocity |
| $m_Q, m_L, L$ | quadrotor mass, payload mass ($m_p$ in the tables), cable length |
| $T$ | cable tension |
| $\boldsymbol F_{wQ}, \boldsymbol F_{wL}$ | wind force on the airframe and on the payload |
| $\boldsymbol d_{mf}, \boldsymbol d_{lf}$ | payload and wind disturbance in the translational dynamics of the controller's model |
| $\boldsymbol\xi$, $\boldsymbol A$, $\boldsymbol B$ | exosystem state of the payload disturbance, its generator and output matrices |
| $\tau$, $\tau_{prev}$ | payload-prediction horizon, reference-preview horizon |
| $K$, $\hat K$ | payload-to-airframe drag-area ratio of the plant, and the value assumed by the controller |
| $P$ | pooled error $\sqrt{\mathrm{mean}_i\, m_i^2}$ over a set of segments |

## 1. Introduction

A small multirotor that lowers a parcel on a cable, or carries rescue equipment under its frame, keeps the agility
of the bare vehicle while the load hangs below it [@sreenath2013]. The price is a coupled, underactuated system in
which the vehicle feels two disturbances at once: the cable force of the swinging load, and the wind, which acts on
the airframe and also on the load, whose drag reaches the vehicle through the cable [@sun2025]. Position accuracy in
this setting decides whether a load can be placed on a target or kept clear of an obstacle.

The established answer to such disturbances is to estimate them and cancel the estimate. Disturbance-observer-based
control separates a controller designed as if the disturbance were known from an observer that supplies it
[@chen2004], and a family of related estimators - disturbance observers, extended state observers and their
variants - follows the same pattern [@chen2016]. When a system is subject to several disturbances of different
nature, lumping them into one equivalent disturbance wastes what is known about each, which motivates composite
schemes with one estimator per disturbance [@chen2016]. The multiple-observer anti-disturbance controller (MOBADC)
of Guo et al. applies this to a quadrotor with a payload: a disturbance observer with a harmonic internal model for
the payload force, an extended state observer for the wind, and an attitude observer [@guo2020]. For a slung load
the internal model is well founded, because the load force along a planned path is periodic [@shi2018; @chen2004].

This paper argues that, once a wind measurement is available, the error that remains under such a controller is set
by two gaps in the controller's model, not by the accuracy of the estimates, and that both gaps can be closed with
knowledge the controller already has.

The first gap is the loop delay. An estimate-and-cancel loop acts on the disturbance one closed-loop delay after the
disturbance occurred. Measurement-based estimators are limited in exactly this way: filtering and actuation delays
bound how fast an estimated force can be cancelled [@smeur2016; @oconnell2022]. For a slow disturbance this lag
costs little. For a payload force that is periodic along a planned trajectory it is a phase error that no faster
estimator can remove, because the estimate is correct and simply late. Yet the same exosystem that lets the observer
represent the periodic force also predicts it: the estimated exosystem state can be propagated over the delay
[@bobtsov2012]. The delay is therefore a modelling gap rather than an estimation limit.

The second gap is the payload's drag. A measured wind turns the wind force into a measurable disturbance, and a
measurable disturbance is best removed by feed-forward [@chen2016]; feed-forward from measured or previewed wind
lowers the position error of a multirotor substantially [@mendez2022]. A feed-forward written for the airframe,
however, omits the force that the wind exerts on the load and the cable passes on to the vehicle. Controllers for
slung loads either neglect the aerodynamic force on the load [@shi2018] or leave it to an estimator together with
everything else [@qian2020; @wang2024; @li2023]; in recent cooperative transport experiments the uncompensated load
drag was the identified cause of the larger tracking error in wind [@sun2025]. The force balance of the coupled
system states how large this force is, so it can be fed forward with the airframe's.

A claim about wind rejection is only as strong as the wind it was tested in. Laboratory fans and jets produce flows
that vary across space and are steady in time [@byun2021], whereas outdoor wind varies in time at a fixed point. The
evaluation here therefore uses wind measured at a meteorological tower, and every claim is tested on data that were
not used to find it [@nosek2018; @munafo2017].

The contributions are:

- **C1 - delay compensation of the payload force (PA-MOBADC).** The disturbance-observer estimate is propagated over
  the measured closed-loop delay through its own exosystem. On fourteen held-out days this lowers the position error
  of MOBADC with measured-wind feed-forward (MOBADC-W) by 58 % on a circle (registered claim).
- **C2 - payload drag in the wind feed-forward (PAW-MOBADC, the proposed method).** The measured-wind feed-forward is
  scaled by $1+\hat K$, the share of the wind force that the coupled force balance assigns to the load. On the
  held-out days it lowers the error of PA-MOBADC by a further 63 % in hover and 37 % on the circle (registered
  claims, found on development data). The complete controller lowers the error of MOBADC on the circle by 78 %, and
  that of MOBADC-W by 75 %.
- **A delimitation of the alternatives.** An acceleration-based disturbance estimate of the INDI type closes neither
  gap on a periodic trajectory, and perfect advance knowledge of the wind leaves no usable headroom at the measured
  heights. The analysis also shows that the closed loop remains bounded under both additions (Section 4.5).

Section 2 positions the work, Section 3 gives the plant, Section 4 the controllers and their boundedness, Section 5
the wind data, statistics and registration. Section 6 reports the results and Section 7 discusses them.

## 2. Related work

**Slung-load control and the load's aerodynamics.** The coordinate-free model of a quadrotor with a cable-suspended
point mass on $SE(3)\times S^2$ is a differentially flat hybrid system with the load position and yaw as flat outputs,
and geometric controllers track the vehicle attitude, the load attitude or the load position with almost-global
properties; the model contains neither wind nor drag [@sreenath2013]. Harmonic extended state observers estimate the
periodic torque that a planar load swing exerts on the attitude, with the aerodynamic force on the load neglected by
assumption; flight tests with a 0.5 kg load on a 1 m cable halved the pitch error [@shi2018]. Surveys and earlier
work collect trajectory shaping, swing damping and learning approaches [@omar2023; @palunko2012; @notter2016;
@faust2017]. Wind on the load has been modelled as linear drag and lumped with other terms into one estimated
disturbance [@qian2020; @wang2024], or represented in a Lagrangian model of a heavy-lift vehicle and a cuboid load
in wind [@gomiero2026]; observers have been combined for the wind and the load [@li2023]. In cooperative transport of
a cable-suspended load by several quadrotors, the onboard controllers estimate and cancel the external force from
the accelerometer, the load is modelled with quadratic drag, and a 5 m/s fan wind raised the load tracking error
because the planner had no wind model; integrating one was named as the remedy [@sun2025].

**Disturbance estimation, delay and prediction.** Disturbance-observer-based control, active disturbance rejection
and related schemes estimate a lumped or modelled disturbance and compensate it [@chen2016; @han2009]; a disturbance
generated by a neutrally stable exosystem, which covers unknown loads and harmonics, is estimated with exponential
convergence by a nonlinear disturbance observer, and the composite controller is semiglobally stable [@chen2004].
The bandwidth of such estimators trades disturbance attenuation against noise [@chen2016]. Measurement-based
estimators of the residual force - incremental nonlinear dynamic inversion (INDI) and $\mathcal L_1$ adaptive
control - adapt fast but are limited by system delay, measurement noise and controller rate [@oconnell2022]. For
INDI the filter delay must be synchronised across the loop, actuator dynamics are handled by the incremental form,
and predictive filtering was set aside because disturbances cannot be predicted [@smeur2016]; the cascaded form also
measures translational disturbances, rejected a 10 m/s windtunnel gust with 0.21 m maximum deviation against 1.51 m
for PID, and is sensitive to accelerometer bias [@smeur2018]. Cancelling a multiharmonic disturbance across a known
input delay by shifting each estimated harmonic ahead is established for nonlinear plants [@bobtsov2012]. C1 applies
this shift to the exosystem state of the payload observer, with the closed-loop delay measured rather than given.

**Wind sensing, feed-forward and preview.** Onboard airspeed sensing has been proposed for wind rejection, with the
caveats of sensor count and low-airspeed reliability [@smeur2018]; a ground-based lidar that previews the incoming
wind fed a trim-based feed-forward that lowered the simulated RMS position error by 43.2 % with an anemometer and
46.4 % with the lidar preview, and observer-based wind estimates were noted to suffer from estimation phase delay
[@mendez2022]. Learned aerodynamic models adapted online improve flight in strong wind [@oconnell2022]. Recording the
disturbance along an outbound flight and feeding it forward on the return lowered the error by 43 % in a steady jet,
under the assumption that the flow varies in space but not in time [@byun2021]. C3 below asks how much advance
knowledge of measured outdoor wind can add beyond a measurement.

## 3. Model

The plant used in every result, P2, couples a rigid quadrotor to a three-dimensional spherical pendulum, the payload on
a rigid massless cable (Fig. 1), and is integrated with a fixed step of 1 ms. Table 1 lists every parameter.

### 3.1 Quadrotor and spherical pendulum

With the cable taut, the quadrotor and the payload obey

$$m_Q\dot{\boldsymbol v}_Q = \boldsymbol F - m_Q g\boldsymbol e_3 + T\boldsymbol q + \boldsymbol F_{wQ} - \boldsymbol F_d$$ {#eq:p2-quad}

$$m_L\ddot{\boldsymbol x}_L = -m_L g\boldsymbol e_3 - T\boldsymbol q + \boldsymbol F_{wL} + \boldsymbol F_d,\qquad \boldsymbol x_L = \boldsymbol x_Q + L\boldsymbol q$$ {#eq:p2-load}

with the cable direction on the sphere

$$\dot{\boldsymbol q} = \boldsymbol\omega\times\boldsymbol q,\qquad \dot{\boldsymbol\omega} = \tfrac{1}{L}\,\boldsymbol q\times\Big[\frac{\boldsymbol F_{wL}+\boldsymbol F_d}{m_L} - \frac{\boldsymbol F + \boldsymbol F_{wQ} - \boldsymbol F_d}{m_Q}\Big]$$ {#eq:p2-sphere}

and the tension that keeps the cable length fixed,

$$T = \mu\Big[\frac{\boldsymbol q\cdot\boldsymbol F_{wL}}{m_L} - \frac{\boldsymbol q\cdot(\boldsymbol F + \boldsymbol F_{wQ})}{m_Q} + L\lVert\dot{\boldsymbol q}\rVert^2\Big],\qquad \mu = \frac{m_Q m_L}{m_Q + m_L}.$$ {#eq:p2-tension}

Without wind and damping these equations reduce to the taut-cable model of Sreenath et al. [@sreenath2013]. A cable
that goes slack ($T \le 0$), where that model becomes hybrid, is flagged and its segment leaves the evaluation. Air
drag alone damps small swings too weakly [@zhu2025], so the cable damping is an internal force on both bodies,

$$\boldsymbol F_d = -c\,L\,(\boldsymbol\omega\times\boldsymbol q),\qquad c = 2\zeta_s\omega_n m_L,\qquad \omega_n = \sqrt{g/L},$$ {#eq:p2-damp}

the viscous damping of a linear oscillator written with its damping ratio, here $\zeta_s = 0.05$. The attitude
dynamics are those of Guo et al. [@guo2020; @raffo2010], with full Euler-angle inertia and Coriolis terms, and the
thrust direction follows the attitude:

$$\boldsymbol M(\boldsymbol\eta)\ddot{\boldsymbol\eta} + \boldsymbol C(\boldsymbol\eta,\dot{\boldsymbol\eta})\dot{\boldsymbol\eta} = \boldsymbol\tau,\qquad \boldsymbol F = f\,\boldsymbol R(\boldsymbol\eta)\boldsymbol e_3.$$ {#eq:rot}

### 3.2 Wind and the two disturbance paths

Both bodies feel quadratic drag on their velocity relative to the air,

$$\boldsymbol F_w = \tfrac12\rho\,(C_DA)\,\lVert\boldsymbol w - \boldsymbol v\rVert(\boldsymbol w - \boldsymbol v),$$ {#eq:drag}

with the airframe's drag area chosen so that it feels 1.0 N in a 5 m/s wind and the payload's drag area a fraction
$K$ of it:

$$\tfrac12\rho(C_DA)_Q = K_w/U_{ref},\qquad (C_DA)_L = K\,(C_DA)_Q.$$ {#eq:drag-cal}

In the controller's model [@guo2020] the disturbances are the cable force and the wind on the airframe,

$$\boldsymbol d_{mf} = T\boldsymbol q - \boldsymbol F_d,\qquad \boldsymbol d_{lf} = \boldsymbol F_{wQ}.$$ {#eq:dist-map}

The wind on the payload is absent from $\boldsymbol d_{lf}$: it reaches the vehicle only through the tension, mixed
into $\boldsymbol d_{mf}$ with the inertial and gravitational load force. This is the gap C2 closes.

### 3.3 Actuators and sensors

Each motor is a first-order lag,

$$\dot f_i = (f_{i,cmd} - f_i)/\tau_m,\qquad \tau_m = 17\ \mathrm{ms},$$ {#eq:motor}

behind the allocation of Guo et al. with rotor-force and torque saturation:

$$[f;\boldsymbol\tau] = \boldsymbol\Gamma[f_1;\dots;f_4],\qquad f_i = \mathrm{sat}_{[0,f_{\max}]}\big(\boldsymbol\Gamma^{-1}[f;\mathrm{sat}(\boldsymbol\tau)]\big).$$ {#eq:alloc}

The attitude reference inverts the force direction with a 30° tilt clamp and a total-thrust limit. The position loop
runs at 125 Hz on motion-capture positions with 8 ms delay, the attitude loop at 1 kHz, and the wind sensor samples
at 20 Hz with one sample of delay:

$$\boldsymbol w_s(t_k) = \boldsymbol w(t_k - 0.05\ \mathrm{s}),\qquad \boldsymbol a_{meas} = \boldsymbol a_Q + \boldsymbol n_a.$$ {#eq:sensors}

The accelerometer returns the inertial acceleration plus noise, without the gravity leakage that an attitude error
causes in a real specific-force measurement. This choice favours the acceleration-based comparison method; its
consequence is quantified with an explicit bias in Section 6.4.

## 4. Controllers

### 4.1 The baseline and its variants

The position law of Guo et al. [@guo2020] is

$$\boldsymbol a_d = \boldsymbol K_\gamma\boldsymbol e_\gamma + \boldsymbol K_v\boldsymbol e_v + g\boldsymbol e_3 + \ddot{\boldsymbol\gamma}_d,\qquad \boldsymbol F = m\boldsymbol a_d - \hat{\boldsymbol d}_{mf} - \hat{\boldsymbol d}_{lf},$$ {#eq:guo-law}

with the published gains (Table 1). The payload estimate $\hat{\boldsymbol d}_{mf}$ comes from a disturbance observer
whose internal model is the exosystem

$$\dot{\boldsymbol\xi} = \boldsymbol A\boldsymbol\xi,\qquad \boldsymbol d_m = \boldsymbol B\boldsymbol\xi,\qquad \boldsymbol A_i = \begin{bmatrix}0&\sigma_i\\-\sigma_i&0\end{bmatrix},$$ {#eq:exo}

with $\sigma$ the angular rate of the planned trajectory, and $\hat{\boldsymbol d}_{lf}$ from a position extended
state observer. The controllers compared are:

| name | definition |
|---|---|
| **PID** | Guo's laws with every estimate switched off |
| **DO**, **ESO** | Guo's controller with only the disturbance observer, or only the two extended state observers |
| **MOBADC** | Guo's controller as published [@guo2020] |
| **MOBADC-DC** | MOBADC with a constant (DC) mode added to the observer's internal model |
| **MOBADC-W** | MOBADC-DC with the measured-wind feed-forward in place of the position observer (Section 4.2) |
| **MOBADC-W + preview** | MOBADC-W with the reference acceleration taken $\tau_{prev}$ ahead |
| **PA-MOBADC** | MOBADC-W with the payload estimate predicted $\tau$ ahead (C1) |
| **PAW-MOBADC** | PA-MOBADC with the payload's drag in the wind feed-forward (C2) - the proposed method |
| **INDI-DE** | INDI-type acceleration-based disturbance estimation (Section 4.6) |

PID and DO are also run with the known payload weight added to their force command ("+ trim"). The DC mode lets the
observer hold the static part of the cable force, which a purely harmonic model cannot represent.

### 4.2 Measured-wind feed-forward

MOBADC-W replaces the position extended state observer by the controller's drag model fed with the measured wind,

$$\hat{\boldsymbol d}_{lf} = \frac{K_w}{U_{ref}}\lVert\boldsymbol w_s - \boldsymbol v_Q\rVert(\boldsymbol w_s - \boldsymbol v_Q).$$ {#eq:wind-ff}

A measured disturbance needs no estimator and therefore no estimator bandwidth [@chen2016]; MOBADC-W is the reference
against which both contributions are measured, because it isolates what the wind measurement alone achieves.

### 4.3 C1 - compensation of the loop delay (PA-MOBADC)

**Why the delay matters.** The force command computed at time $t$ acts on the vehicle after a closed-loop delay
$\tau_d$ (sampling, motor lag, attitude response). Without prediction the compensation error at the moment the
command acts is

$$\boldsymbol e_{mf}(t) = \boldsymbol d_{mf}(t+\tau_d) - \boldsymbol B\hat{\boldsymbol\xi}(t) = \boldsymbol B\tilde{\boldsymbol\xi}(t) + \big[\boldsymbol d_{mf}(t+\tau_d) - \boldsymbol d_{mf}(t)\big],\qquad \tilde{\boldsymbol\xi} = \boldsymbol\xi - \hat{\boldsymbol\xi}.$$ {#eq:lag-err}

The bracket does not vanish when the observer is exact. For one harmonic of amplitude $a$ and frequency $\sigma$ its
magnitude is $2a\,|\sin(\sigma\tau_d/2)|$; on the circle of this study ($\sigma = 1.575$ rad/s) and with the delay
measured below ($\tau_d = 290$ ms) this is 0.45 of the amplitude. A perfect estimate applied late leaves almost half of
the periodic payload force uncancelled, and a faster estimator cannot change that.

**Prediction through the exosystem.** The observer's internal model is the generator of the disturbance, so the
estimate can be carried over the delay with it:

$$\hat{\boldsymbol d}_{mf}(t+\tau) = \boldsymbol B\,e^{\boldsymbol A\tau}\hat{\boldsymbol\xi}(t).$$ {#eq:pred}

Each $2\times2$ block of $e^{\boldsymbol A\tau}$ is a rotation, so the prediction costs two trigonometric evaluations
per mode, and the DC mode is unchanged. For a harmonic mode this is the shift of Bobtsov and Pyrkin [@bobtsov2012]
with unit gain and no plant phase, because the payload force enters the force channel directly.

**Proposition 1 (prediction does not amplify the estimation error).** Let $\boldsymbol A$ be block diagonal with zero
and skew-symmetric $2\times2$ blocks. With $\tau = \tau_d$ the compensation error of (@eq:pred) is

$$\boldsymbol e_{mf}(t) = \boldsymbol B\,e^{\boldsymbol A\tau}\tilde{\boldsymbol\xi}(t) + \big[\boldsymbol d_{mf}(t+\tau) - \boldsymbol B\,e^{\boldsymbol A\tau}\boldsymbol\xi(t)\big],\qquad \lVert\boldsymbol B\,e^{\boldsymbol A\tau}\tilde{\boldsymbol\xi}(t)\rVert \le \lVert\boldsymbol B\rVert\,\lVert\tilde{\boldsymbol\xi}(t)\rVert .$$ {#eq:pred-err}

*Proof.* $e^{\boldsymbol A\tau}$ is block diagonal with identity and rotation blocks, hence orthogonal, so
$\lVert e^{\boldsymbol A\tau}\boldsymbol x\rVert = \lVert\boldsymbol x\rVert$ for every $\boldsymbol x$ and every
$\tau$; the bound follows from $\lVert\boldsymbol B\boldsymbol y\rVert \le \lVert\boldsymbol B\rVert\lVert\boldsymbol
y\rVert$. $\square$

The estimation part of the error is therefore no larger than without prediction, for any horizon, while the bracket -
the deviation of the true force from the exosystem over the horizon - is zero for a force that follows the internal
model and replaces the lag term of (@eq:lag-err) otherwise. Prediction trades a phase error that is certain for a
model error that is small when the internal model is right. The horizon was measured on the development set by a
registered sweep (Section 6.2): $\tau = 290$ ms on the circle; in hover, where the payload force has no orbital
frequency, the minimum lies at $\tau = 0$.

### 4.4 C2 - payload drag in the wind feed-forward (PAW-MOBADC, the proposed method)

The feed-forward of Section 4.2 accounts for the wind on the airframe only. Adding (@eq:p2-quad) and (@eq:p2-load)
removes the tension and the cable damping, which are internal forces of the two-body system:

$$m_Q\dot{\boldsymbol v}_Q + m_L\ddot{\boldsymbol x}_L = \boldsymbol F - (m_Q+m_L)g\boldsymbol e_3 + \boldsymbol F_{wQ} + \boldsymbol F_{wL}.$$ {#eq:balance}

The thrust must therefore balance the wind force on both bodies. The payload's drag area is $K$ times the
airframe's (@eq:drag-cal); when the payload meets the same wind with the velocity of the vehicle, (@eq:drag) gives
$\boldsymbol F_{wL} = K\boldsymbol F_{wQ}$, and the wind force the thrust has to balance is $(1+K)\boldsymbol F_{wQ}$.
The controller uses its assumed ratio $\hat K$ and scales the measured-wind term:

$$\hat{\boldsymbol d}_{lf} = (1+\hat K)\,\frac{K_w}{U_{ref}}\lVert\boldsymbol w_s - \boldsymbol v_Q\rVert(\boldsymbol w_s - \boldsymbol v_Q),\qquad \hat K = 0.5.$$ {#eq:paw-ff}

**Proposition 2 (residual of the static term).** With $\boldsymbol r_Q = \boldsymbol w - \boldsymbol v_Q$,
$\boldsymbol r_L = \boldsymbol w - \boldsymbol v_L$ and $k = K_w/U_{ref}$, the part of the payload's wind force that
(@eq:paw-ff) leaves uncompensated, measurement delay apart, is

$$\boldsymbol F_{wL} - \hat K k\lVert\boldsymbol r_Q\rVert\boldsymbol r_Q = (K-\hat K)\,k\lVert\boldsymbol r_Q\rVert\boldsymbol r_Q + K k\big(\lVert\boldsymbol r_L\rVert\boldsymbol r_L - \lVert\boldsymbol r_Q\rVert\boldsymbol r_Q\big),\qquad \big\lVert\lVert\boldsymbol r_L\rVert\boldsymbol r_L - \lVert\boldsymbol r_Q\rVert\boldsymbol r_Q\big\rVert \le \big(\lVert\boldsymbol r_L\rVert + \lVert\boldsymbol r_Q\rVert\big)\,L\lVert\boldsymbol\omega\rVert .$$ {#eq:ff-err}

*Proof.* The decomposition is algebraic. For the bound, $\lVert\boldsymbol a\rVert\boldsymbol a - \lVert\boldsymbol
b\rVert\boldsymbol b = \lVert\boldsymbol a\rVert(\boldsymbol a - \boldsymbol b) + (\lVert\boldsymbol a\rVert -
\lVert\boldsymbol b\rVert)\boldsymbol b$, whose norm is at most $(\lVert\boldsymbol a\rVert + \lVert\boldsymbol
b\rVert)\lVert\boldsymbol a - \boldsymbol b\rVert$, and $\boldsymbol r_Q - \boldsymbol r_L = \boldsymbol v_L -
\boldsymbol v_Q = L\,\boldsymbol\omega\times\boldsymbol q$ has norm at most $L\lVert\boldsymbol\omega\rVert$. $\square$

The residual has two sources: a wrong assumed ratio, which is proportional to the feed-forward itself, and the
relative motion of the load, which is proportional to the swing rate. The static term is exact for a load that moves
with the vehicle and degrades gracefully with swing; Section 6.3 measures both sources by varying $\hat K$ and by
flying trajectories with different swing.

### 4.5 Boundedness of the closed loop

Both additions change only the compensation signal $\hat{\boldsymbol d}_{mf} + \hat{\boldsymbol d}_{lf}$ in
(@eq:guo-law); the feedback laws, the observers and their gains are those of Guo et al. Let $\boldsymbol e_d$ be the
total compensation error at the moment the command acts. If the translational and attitude loops of the baseline are
input-to-state stable with respect to $\boldsymbol e_d$, with gain $\gamma$, the tracking error of every controller in
Section 4.1 is ultimately bounded by $\gamma(\sup_t\lVert\boldsymbol e_d(t)\rVert)$, and the question reduces to the
size of $\boldsymbol e_d$:

$$\lVert\boldsymbol e_d\rVert \le \lVert\boldsymbol B\rVert\,\lVert\tilde{\boldsymbol\xi}\rVert + \lVert\boldsymbol d_{mf}(t+\tau) - \boldsymbol B e^{\boldsymbol A\tau}\boldsymbol\xi(t)\rVert + \lVert\boldsymbol F_{wQ}(t+\tau_d) - \hat{\boldsymbol d}_{lf}(t)\rVert .$$ {#eq:ed-bound}

The first term is bounded because the observer's error dynamics are stable and driven by the bounded mismatch
between the payload force and the exosystem [@chen2004], and Proposition 1 shows that prediction does not enlarge
it; the second because the payload force and the exosystem output are bounded on bounded trajectories. The third
contains, by design, the excess $\hat K k\lVert\boldsymbol r_Q\rVert\boldsymbol r_Q$ that offsets the load's wind
force carried by $\boldsymbol d_{mf}$ through the tension; it is bounded because the wind and the velocities are
bounded, and Proposition 2 bounds what the offset leaves. Neither addition can therefore destabilise a loop that is
input-to-state stable with respect to its compensation error; both move the ultimate bound, which is what Section 6
measures. The assumption concerns the baseline alone: it is the property on which composite disturbance-observer
controllers rest [@chen2004], examined for this baseline by its authors [@guo2020]. Section 6.7 shows that it fails
for the published gains at motor lags of 25 ms and above, independently of either addition.

### 4.6 Comparison methods

**INDI-DE** estimates the total disturbance from the measured acceleration, as the outer loop of incremental
nonlinear dynamic inversion [@smeur2018]:

$$\hat{\boldsymbol d}_{mf} = H(z)\big[m\boldsymbol a_{meas} - \hat{\boldsymbol F}_{thr} + mg\boldsymbol e_3\big],\qquad \hat{\boldsymbol d}_{lf} = 0,$$ {#eq:h3}

with $H$ a second-order low-pass filter whose cut-off, 32 Hz, is the best value of a registered sweep and therefore
chosen in favour of the competitor, and the thrust estimated through the nominal motor lag. Guo's attitude loop is
kept; there is no inner INDI loop. **MBP** (model-based payload predictor) replaces the static term of C2 by an
open-loop pendulum prediction of the payload force. **The oracle** of C3 feeds the wind channel with the true future
wind,

$$\hat{\boldsymbol d}_{lf} = \frac{K_w}{U_{ref}}\lVert\boldsymbol w(t+\tau_w) - \boldsymbol v_Q\rVert(\boldsymbol w(t+\tau_w) - \boldsymbol v_Q),$$ {#eq:oracle}

an upper bound on what any wind predictor could add through the controller's force model.

## 5. Experimental design

### 5.1 Wind data and segments

Measured wind comes from the sonic anemometers of the M5 tower at the National Wind Technology Center of NREL, at
heights of 61 and 74 m, sampled at 20 Hz [@hamilton2019]. Each run lasts 200 s; statistics use $t \ge 140$ s. A
segment enters a trajectory's set only if the vehicle can hold the trajectory against the static wind force at the
segment's mean wind speed with tilt and thrust within 80 % of their limits; on the circle (radius 0.8 m, angular rate
1.575 rad/s) this admits mean winds up to 8.02 m/s (Fig. 2).

- **Development pool:** 471 segments from 46 days. Every horizon, every post-hoc finding and every development-set
  number comes from it. The main circle set holds 134 segments (42 days, at most four per day), the hover set 139
  segments (43 days); sensitivity tables use one segment per day (40 on the circle, 43 in hover).
- **Held-out set:** 14 days chosen by a hash rule before download and opened once, after every claim, threshold and
  runner had been frozen. Two further days of the manifest had been inspected segment by segment while the wind
  pipeline was built and were excluded before any controller run; the remaining days had contributed only to pooled
  wind statistics of that earlier stage [@nosek2018].

### 5.2 Metric and statistics

The metric of a segment is the mean position-error norm over the window,

$$m_i = \operatorname{mean}_{t\ge140}\lVert\boldsymbol\gamma_d - \boldsymbol\gamma\rVert,$$ {#eq:metric}

pooled over a set as

$$P = \sqrt{\operatorname{mean}_i m_i^2},\qquad \Delta = P_a/P_b - 1,\qquad h = 1 - P_b/P_a.$$ {#eq:pool}

Because segments of one day share weather, every ratio carries a paired delete-one-day jackknife standard error,

$$\mathrm{SE} = \sqrt{\tfrac{D-1}{D}\textstyle\sum_{d=1}^{D}(\hat\theta_{(-d)} - \bar\theta)^2},$$ {#eq:jack}

with $D$ the number of days, beside the range of leave-one-segment-out values and the median of the per-day values.
One table is scored on one set of segments: a segment on which any column fails leaves that table. The control effort
is reported as the RMS oscillation of the commanded rotor forces about their own means, and the payload swing as the
RMS cable angle.

### 5.3 Registration and held-out confirmation

Each claim was written, with its test and threshold, in a dated register before its data were opened; a finding made
after seeing development data was labelled post hoc and could only become a claim by being registered and tested on
the held-out days [@nosek2018; @munafo2017]. The held-out claims are:

- **D2** (C1): $\Delta$ = PA-MOBADC / MOBADC-W − 1 on the circle; confirmed if $\Delta \le -15$ % and
  $\Delta$ + 1.65 SE < 0.
- **H-static** and **H-static-circle** (C2): $h$ = 1 − PAW-MOBADC / PA-MOBADC, in hover and on the circle, scored on
  the segments where PA-MOBADC is not at its tilt clamp; confirmed if the per-day median is at least 10 %,
  $h$ − 1.65 SE > 0, and PAW-MOBADC fails on at most one segment where PA-MOBADC runs.
- **H-hover** (C3, one post-hoc group): $h$ = 1 − oracle / PA-MOBADC in strong hover wind relative to the envelope.

Every registered test with a pass/fail outcome is reported as it stands. 2 of the 7 registered predictions scored in
this paper were missed: the C3 headroom gate (no group had headroom) and the acceptance of MBP.

| where | scored | missed |
|---|---|---|
| development gates: D2 gate, C3 headroom gate, MBP acceptance, eligibility of PAW-MOBADC for the held-out test | 4 | 2 |
| held-out claims: D2, H-static, H-static-circle (H-hover not scorable: one segment) | 3 | 0 |

### 5.4 Reproduction

The development-set results were computed twice. After the original runs, the complete pipeline - download of the
public wind records, export of the segments, measurement of every horizon and every simulation - was executed again,
independently, on a different operating system. All 39 development-set statistics of Section 6 agree to the printed
digit between the two executions, and the additional checks of Section 6.3 come from the second one.

### 5.5 Use of AI-assisted tools

AI-assisted tools were used to help write the simulation and analysis code and to edit the manuscript. The design of
the study, the registered claims, the analyses and the conclusions are the authors', who checked every result and
take full responsibility for the content.

## 6. Results

### 6.1 Main comparison

**The proposed PAW-MOBADC lowers the pooled error of MOBADC on the circle from 0.0451 m to 0.0120 m, by 73.42 %
(SE 6.34), on the development set (133 segments on 42 days), and from 0.0405 m to 0.00873 m, by 78.44 % (SE 0.61),
on the 56 held-out segments.** These comparisons are descriptive; the registered claims are the two steps of
Sections 6.2 and 6.3.

Table 2 ranks eight controllers on the 133-segment development circle. PID tracks with a pooled error of 0.201 m,
DO 0.184 m, ESO 0.0758 m and MOBADC 0.0451 m; the known-weight trims lower PID and DO to 0.153 m and 0.140 m, and
INDI-DE reaches 0.0384 m. MOBADC has the lowest error of Guo's four controllers, as in their indoor test [@guo2020],
but ESO now ranks above DO and PID, whereas it ranked below PID indoors. The difference is consistent with the
character of the wind: a fan flow varies across the room, so the vehicle meets the same gust once per lap
[@byun2021], whereas measured outdoor wind varies slowly in time, which suits an extended state observer's slowly
varying estimate. Fig. 3 shows the trajectories on one segment chosen by a registered rule: PAW-MOBADC stays on the
desired circle, INDI-DE flies a circle offset outwards, and the baselines drift with the wind, and Fig. 4 shows the
position error and payload angle on one held-out segment. Against MOBADC-W, the stronger reference because it
already uses the wind measurement, the complete controller lowers the error by 74.57 % (SE 1.83) on the held-out
circle (Table 3).

### 6.2 C1 - compensation of the loop delay

The registered development gate D2 passed: PA-MOBADC lowered the pooled error of MOBADC-W by 50.33 % (SE 8.28,
by-day median −62.23 %), from 0.0363 m to 0.0180 m. **On the held-out days D2 was confirmed: −58.30 % (SE 4.57,
leave-one-out range [−60.66, −58.12], by-day median −63.88 %), from 0.0343 m to 0.0143 m** (Table 4, Fig. 5). The size
of the gain agrees with the argument of Section 4.3: a 290 ms delay leaves 0.45 of a harmonic payload force
uncancelled, and prediction removes most of it. The horizon itself comes from the registered sweep of Fig. 6: on the
circle the pooled error has its minimum at 290 ms, in hover at the lower edge of the grid, $\tau = 0$.

The gain holds on the other planned trajectories, −45.41 % on the figure-eight and −24.80 % on the square, and across
every payload mass, cable length and their combinations, between −58.9 % and −34.9 % (Table 5). It is smallest where
the payload is light and the cable long, that is, where the periodic payload force is smallest relative to the wind.
The reference preview (MOBADC-W + preview) compensates the same delay along the planned trajectory and gives a
comparable gain, −62.40 % on the held-out days; Section 7.2 compares the two realisations.

### 6.3 C2 - payload drag in the wind feed-forward

**Found post hoc on the development set.** PAW-MOBADC was first a comparison column of the MBP test (Section 6.6). In
hover, on the development segments where PA-MOBADC is below its tilt clamp, it lowered the error of PA-MOBADC by
65.68 % (SE 1.59); on the full hover set the value was +20.27 % (SE 42.39), pulled down by one segment at the actuator
limit on which both controllers saturate (Table 3). On the circle (one segment per day) it lowered the error by
43.67 % (SE 2.16).

**Registered and confirmed on the held-out days.** Both claims were registered from these numbers before the
held-out days were opened. H-static (hover) was confirmed with $h$ = +63.00 % (SE 1.37, 52 segments on 14 days, no
failure), H-static-circle with +37.18 % (SE 3.04, 53 segments, no failure). On the full held-out sets the error falls
from 0.0143 m to 0.00873 m on the circle and from 0.0106 m to 0.00385 m in hover (Fig. 7). Table 3 separates the steps: on the
held-out circle C1 gives −58.30 % against MOBADC-W and C2 a further −39.00 %. In hover the registered horizon is
$\tau = 0$, so PA-MOBADC equals MOBADC-W there and the whole gain over MOBADC-W is C2's.

**What the static term depends on.** Proposition 2 names two sources of residual, the assumed ratio and the swing;
Table 6 collects the checks that probe them.

- *Assumed ratio.* With $\hat K$ scaled by 0.7 and 1.3 the gain stays at 55.81 % and 59.00 % in hover (against
  67.51 % at the nominal ratio), and at 34.76 % and 46.70 % on the circle (against 43.67 %). Underestimating the
  load's drag costs more than overestimating it, and neither removes most of the gain.
- *Swing and trajectory.* With the payload drag in the feed-forward the error falls by 56.37 % on the figure-eight
  and by 15.03 % on the square (development sets, PAW-MOBADC against PA-MOBADC). The square, whose corners excite the
  largest swing, is where the term helps least, as the swing-rate bound of Proposition 2 predicts.
- *Payload mass and cable length.* Across the eight sensitivity levels on the circle the gain lies between 21.64 %
  (light payload, long cable) and 52.33 % (short cable), and PAW-MOBADC lowers the error of MOBADC-W by 48.91 % to
  80.32 %; the light-payload levels are pooled on the segments inside their wind envelope, as in Table 5. The gain
  grows with the share of the load's drag in the wind force the vehicle has to balance.
- *Wind-sensor noise.* With 0.1 m/s noise on the wind sensor the gain is 42.98 % on the circle and 65.36 % in hover,
  against 43.67 % and 67.51 % without noise.
- *Reference preview.* Added to the preview instead of to the prediction, the payload-drag term lowers the error by
  28.80 % on the circle, 49.73 % on the figure-eight and 15.25 % on the square: C2 is independent of how the delay is
  compensated.

### 6.4 Measurement versus prediction: INDI-DE

The two kinds of disturbance separate the methods. **On the circle**, where the payload force is periodic and fast
compared with the loop delay, prediction wins: on the held-out days INDI-DE's pooled error is 37.2 mm, against
14.3 mm for PA-MOBADC and 8.73 mm for PAW-MOBADC (INDI-DE is 159.54 % above PA-MOBADC; 112.93 % on the development
set; Fig. 8). INDI-DE's error is nearly the same on every circle segment whatever the wind, which identifies its source: it
measures the trajectory-driven payload force correctly and one loop delay late, the lag term of (@eq:lag-err).
**In hover**, where the disturbance is slow, fast measurement is enough: INDI-DE reaches 2.60 mm, against 3.85 mm for
PAW-MOBADC and 10.6 mm for PA-MOBADC. This advantage depends on the idealised accelerometer of Section 3.3. A
horizontal accelerometer bias of 0.086 m/s² or 0.17 m/s², the gravity leakage of an attitude error of 0.50° or 0.99°,
raises INDI-DE's error to 7.66 mm and 14.5 mm, above PAW-MOBADC, in agreement with the bias sensitivity of outer-loop
INDI [@smeur2018].

### 6.5 Advance knowledge of the wind (C3)

Knowing the true future wind adds almost nothing once the wind is measured. In the registered headroom test the
oracle lowered the error of PA-MOBADC by 0.69 % on the circle and by 2.87 % in hover with the wind-to-payload term
(Fig. 9). The largest headroom among the eleven evaluable groups was 5.83 % (a post-hoc group), below the registered
threshold of 10 %, so no group met the headroom rule. On the unsaturated segments of one post-hoc group, strong hover
wind relative to the envelope, the oracle gained 41.52 % (10 development segments); the held-out days held a single
usable segment in that wind band, so H-hover was not confirmable.

### 6.6 Model-based payload prediction (MBP)

Predicting the payload force with an open-loop pendulum model did not pass its registered test: in hover it was worse
than PA-MOBADC on the full set ($h$ = −158.83 %, SE 200.46), although better on the unsaturated segments (+72.72 %),
and on the circle its error was 222.33 % above PA-MOBADC. A model of the load that runs open loop diverges from the
real swing, whereas the static term of C2 and the observer of C1 both stay tied to measurements.

### 6.7 Motor lag and the published gains

With Guo's gains [@guo2020] the full plant stayed stable on all ten registered runs at a motor lag of 17 ms and
diverged on all ten at 25 ms and at 30 ms. Guo et al. flew these gains stably [@guo2020]; a motor lag of 17 ms is
consistent with that and is used throughout. The result agrees with the observation that position and attitude gains
are not free once actuator dynamics are taken into account [@smeur2018], and it marks where the boundedness
assumption of Section 4.5 holds for this baseline.

### 6.8 Control effort and payload swing

On the held-out days PAW-MOBADC uses more control effort: the RMS oscillation of the rotor forces is 0.611 N on the
circle, against 0.532 N for MOBADC, 0.579 N for PA-MOBADC and 0.543 N for INDI-DE, and 0.556 N in hover, against
0.532 N for PA-MOBADC and 0.503 N for INDI-DE. On the circle this is about 15 % more effort than MOBADC for a 78 %
lower position error. The payload's RMS angle is almost the same for every controller: 16.24–16.88° on the circle,
where it is mostly the steady cone angle of about 15°, and 7.99–8.03° in hover.

## 7. Discussion

### 7.1 When to predict and when to measure

The circle and hover results follow one rule: a disturbance that is periodic and fast compared with the loop delay
has to be predicted, and a slow one can be measured. Prediction uses knowledge the controller already holds - the
frequency in its internal model - and costs two trigonometric evaluations per mode; Proposition 1 guarantees that it
does not amplify the observer's error. Measurement needs no model of the disturbance but arrives one delay late, which
on a planned trajectory leaves the error that INDI-DE shows on the circle, and it inherits the accelerometer's bias,
which removes its advantage in hover at an attitude error of half a degree. The view that disturbances cannot be
predicted [@smeur2016] holds for disturbances without structure; a payload force on a planned path has structure that
the observer has already identified.

### 7.2 Two realisations of delay compensation

On a planned trajectory the loop delay can be compensated inside the observer (PA-MOBADC) or by feeding forward the
reference acceleration one horizon ahead (MOBADC-W + preview). On the held-out days they give −58.30 % and −62.40 %
against MOBADC-W, on the development set −50.33 % and −53.95 %; the two values differ by less than the standard error
of either. Both need advance knowledge - the frequency of the payload force or the future trajectory - so neither
applies to trajectories that are not planned. PAW-MOBADC uses prediction because it works inside the observer with the
frequency the observer already holds and leaves the reference and the trajectory generator unchanged. The
payload-drag term combines with either: added to the preview it lowers the error by 28.80 % on the circle
(Section 6.3).

### 7.3 Robustness of the payload-drag term

The term multiplies the measured airframe wind force by $1+\hat K$. Its gain survives a 30 % error in the assumed
drag ratio, a 0.1 m/s wind-sensor noise and the full range of payload masses and cable lengths tested, which is what
Proposition 2 leads one to expect for a residual proportional to the ratio error and to the swing rate. The same
multiplication passes measurement spikes to the force command: on one development segment of the circle and one of
hover, both carrying single-sample spikes in the wind record, PAW-MOBADC stopped the solver while PA-MOBADC completed
the run; none of the held-out segments produced a failure. A causal filter that holds a sample whose step exceeds
5 m/s did not remove these failures at no cost - it moved them to other segments, on two of which PA-MOBADC itself
diverged with the filtered wind - and the gain was unchanged (38.00 % on the circle and 65.65 % in hover on the
unsaturated segments, against 38.20 % and 65.68 % without the filter). A wind sensor for this term therefore needs
spike handling designed with the controller, not a generic filter.

### 7.4 What advance wind knowledge can add

For the 61–74 m wind of this dataset the measured-wind channel is already close to the oracle: the sensor delay is
one sample, and the static drag model passes the low-frequency wind that dominates the force. The error that remains
is the payload's own dynamics, which C1 and C2 address. Wind nearer the ground carries more energy at high frequency
and may leave more headroom for prediction, as the strong-wind hover group suggests; the held-out days did not contain
enough such wind to test it.

### 7.5 Scope

The results are simulation results, and the comparisons are designed so that the conclusions do not depend on
favourable modelling: the accelerometer is ideal, which favours the acceleration-based competitor; the competitor's
filter is the best value of a sweep; and the baseline's published gains are used unchanged. The method improves the
position of the vehicle, not the swing of the load, whose RMS angle is the same for every controller; damping the
swing calls for feedback of the cable angle [@sreenath2013]. Results hold for planned trajectories and hover. The
held-out days had entered pooled wind statistics of an earlier stage of the project, and the two days inspected there
in detail were removed before any controller run; the held-out confirmations rest on fourteen days.

## 8. Conclusion

On a quadrotor with a slung load in measured wind, the error that remains under an observer-based controller with a
wind measurement is set by two model gaps, and both can be closed with knowledge the controller already has. Propagating
the payload estimate over the loop delay through the observer's exosystem lowers the error of the measured-wind
controller by 58 % on fourteen held-out days, and adding the payload's drag to the wind feed-forward lowers it by a
further 63 % in hover and 37 % on the circle; both steps were registered and confirmed on the held-out days, the
second after being found on development data. The complete controller, PAW-MOBADC, lowers the error of the
multiple-observer controller of Guo et al. on the circle by 78 % at about 15 % higher control effort, and neither
addition can destabilise a baseline that is input-to-state stable with respect to its compensation error.

For practitioners:

1. Compensate the loop delay for a periodic payload force: predict the observer's estimate through its exosystem, or
   preview the planned reference (−58 % and −62 % on the held-out days).
2. Put the payload's drag into the wind feed-forward; an assumed drag ratio 30 % too low or too high keeps most of
   the gain.
3. Expect little from predicting the wind at 61–74 m height: perfect foresight gained at most 6 % in any wind group.
4. Use an acceleration-based estimate for slow disturbances in hover only if the attitude error is well below 0.5°.
5. Check published gains against the motor lag of the platform: the baseline gains are stable at 17 ms and diverge
   from 25 ms.

Flight tests, wind measured near the ground, and swing damping are the next steps.

## Figure captions

**Fig. 1** (`p2_fig1_system`). Plant P2 (quadrotor coupled to a three-dimensional spherical pendulum, both under
quadratic drag) and the controller with the compared estimates.

**Fig. 2** (`p2_fig2_wind`). Wind data: mean wind speed and turbulence intensity per segment, development pool and
held-out days, with the operating envelopes.

**Fig. 3** (`p2_fig9_traj`). The six controllers of Table 2 on one development circle segment (chosen by a registered
rule).

**Fig. 4** (`p2_fig3_series`). One held-out circle segment (chosen by a registered rule): position error and payload
angle of MOBADC-W, PA-MOBADC, PAW-MOBADC and INDI-DE.

**Fig. 5** (`p2_fig4_c1`). C1: PA-MOBADC / MOBADC-W − 1 and the reference preview, per trajectory, development set and
held-out days; per-segment comparison.

**Fig. 6** (`p2_fig5_tau`). Pooled error against the prediction horizon, development segments; the chosen horizon is
marked.

**Fig. 7** (`p2_fig6_c2`). C2: gain of PAW-MOBADC over PA-MOBADC with ±1.65 SE, development (post hoc) and held-out
(registered); control effort and payload angle.

**Fig. 8** (`p2_fig7_fast`). PA-MOBADC, PAW-MOBADC and INDI-DE on the circle and in hover.

**Fig. 9** (`p2_fig8_c3`). C3: headroom of perfect advance wind knowledge in the twelve registered wind groups.

## Data and code availability

The wind records are public (NREL National Wind Technology Center M5 tower data). The code, the registers and the
result files will be made available upon acceptance.

## Appendix A. Components added to the simulation model

Every component that this work adds to the simulation model of the baseline is inserted by one named script, and
nothing else in the model is. Inherited from Guo et al., unchanged: the rigid-body model, the attitude and position
laws with every gain, the position and attitude observers, the disturbance observer with its one-harmonic exosystem,
and the composition of (@eq:guo-law).

| component | inserted by | used in this paper |
|---|---|---|
| plant P2 (spherical pendulum, quadratic drag, motor lag, sensors, discrete loops), the controller's quadratic wind model with its $(1+\hat K)$ scale, the INDI-DE and MBP blocks, the wind-to-payload term of C3 and the known-weight trim | `build_p2_plant` | yes - Sections 3, 4.2–4.6 |
| DC mode of the observer's internal model | `build_do_matrices` | yes - MOBADC-DC and every variant after it |
| payload predictor $\boldsymbol B e^{\boldsymbol A\tau}\hat{\boldsymbol\xi}$ | `build_payload_predictor` | yes - C1 |
| measured-wind path into $\hat{\boldsymbol d}_{lf}$ (made quadratic through `build_p2_plant`) | `build_pa_mobadc` | yes - MOBADC-W |
| reference preview $\ddot{\boldsymbol\gamma}_d(t+\tau_{prev})$ | `build_traj_preview` | yes - MOBADC-W + preview |
| trajectory shapes (hover, circle, figure-eight, square, multi-sine) | `build_traj5` | yes |
| measured wind series | `build_wind_series` | yes |
| frozen learned wind predictor | `build_wind_predictor` | C3 only |
| wind-sensor noise injection | `build_wind_sensor_noise` | Section 6.3 (0.1 m/s) only |
| inactive blocks kept from an earlier version of the model, switched off in every run | `build_payload_pendulum`, `build_payload_wind`, `build_payload_inject`, `build_im_est_online` | no |
| probes on the wind estimate and on the vehicle acceleration | `build_dlf_probe`, `build_nu_dot_log` | instrumentation only |
| tilt, thrust, rotor and torque limits | `thrust_attitude_ref`, `motor_allocation` | yes - Section 3.3 |

## References

::: {#refs}
:::
