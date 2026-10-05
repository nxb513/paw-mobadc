function E = expected_baseline()
%EXPECTED_BASELINE  The SINGLE source for the expected baseline numbers.
%
%   E = expected_baseline
%
%  Before this file, the expected MOBADC number appeared in three places with
%  TWO different values:
%     core/init_MOBADC_params.m header      0.0234
%     baseline_table.txt, last line         0.0234
%     experiments/run_test4_payload.m REF   0.0228   <- and this was the
%                                                       measured one
%  There was no way to tell which was true. Now there is one place to change.
%
%  E.repro   the number MEASURED by run_baseline on baseline1.slx
%            (the regression gate)
%  E.tol     the tolerance of that gate
%  E.paper   the number published in Guo et al., CEP 2020, Table 1 (Test 4)
%
%  ------------------------------------------------------------------
%  WARNING ABOUT E.paper - READ BEFORE COMPARING
%  ------------------------------------------------------------------
%  The reproduction does NOT match the published table, and on the ESO row it
%  does not even match the ORDER:
%
%              published   reproduced
%     Classical  0.1502      0.0939
%     ESO        0.2054      0.0587     <-- published: ESO WORSE than Classical
%     DO         0.0725      0.0732         reproduced: ESO BETTER
%     MOBADC     0.0350      0.0228
%
%  The DO row agrees to ~1%, and it is the ONLY row derivable from the
%  reference work's Appendix (d/(m*Kgamma) = 0.0743). The other three cannot be
%  derived, because that work publishes neither the tether length, nor the
%  payload swing amplitude, nor the magnitude of the wind force.
%
%  A reproduction that matches one row out of four and REVERSES the order on
%  another cannot be called a reproduction without saying so. check_paper_
%  divergence() prints this warning on every run, so that it is never quiet in
%  a report.
%
%  ------------------------------------------------------------------
%  THE NUMBERS HERE ARE THE LABORATORY CONDITION, NOT THE PAPER'S TABLE 5
%  ------------------------------------------------------------------
%  E.repro is measured on the SINUSOIDAL payload at the laboratory operating
%  point - it is the regression gate for baseline1.slx and nothing else. The
%  paper's five-controller table (Table 4, and the comparison in Table 5) is a
%  DIFFERENT experiment: outdoor, measured wind, physical pendulum, and its
%  Classical row is 0.1466 rather than 0.0939. Reading a number from here into
%  a paper table, or the reverse, compares two different experiments.
%
%  The manuscript states the same three reasons this is not a reproduction, in
%  docs/RESULTS.md R3.4 and Section 2.6 of the manuscript. In particular:
%  inverting our two-disturbance structure against the published table needs
%  A ~ 3.66 N to explain its Classical row and A ~ 5.71 N to explain its ESO
%  row. No single amplitude satisfies both, so "two of four rows land close" is
%  an arithmetic consequence of the amplitude WE chose (1.5 N), not evidence of
%  agreement. Do not restate it here as a structural result - that phrasing was
%  withdrawn and tools/check_retracted.py now blocks its return.

E.repro = struct( ...
    'Classical', struct('mean', 0.0939, 'std', 0.0285, 'max', 0.1448), ...
    'ESO',       struct('mean', 0.0587, 'std', 0.0281, 'max', 0.0923), ...
    'DO',        struct('mean', 0.0732, 'std', 0.0150, 'max', 0.0949), ...
    'MOBADC',    struct('mean', 0.0228, 'std', 0.0067, 'max', 0.0314));

% An absolute 5e-4 is 2.2% on MOBADC (0.0228) but only 0.5% on Classical. Use a
% RELATIVE tolerance so the gate bites equally hard on all four rows.
E.tol_rel = 0.01;      % 1% relative
E.tol_abs = 2e-4;      % absolute floor, for the small rows

E.paper = struct( ...
    'Classical', struct('mean', 0.1502, 'std', 0.0700), ...
    'ESO',       struct('mean', 0.2054, 'std', 0.0205), ...
    'DO',        struct('mean', 0.0725, 'std', 0.0480), ...
    'MOBADC',    struct('mean', 0.0350, 'std', 0.0202));

E.names = {'Classical','ESO','DO','MOBADC'};

%% ---- Pendulum branch (payload_model = 1), from payload_model_table.txt ----
% MOBADC DEPENDS ON L: there is no single number for the pendulum branch. The
% reproduction gate in run_test5_predictor must look the value up by the L in
% use, otherwise it compares the L = 1.0 branch against the L = 0.8 number and
% reports a failure that is not one.
E.pendulum_L      = [0.800 1.000 1.200 1.445 1.800];
E.pendulum_MOBADC = [0.0238 0.0243 0.0248 0.0254 0.0266];
end
