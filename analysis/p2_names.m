function out = p2_names(in)
%P2_NAMES  Name in the paper of an internal column / controller code (REGISTER_P2 sec 63.1).
%
%   p2_names('L3_iii0')              -> 'PAW-MOBADC'
%   p2_names({'L2', 'L3', 'H3'})     -> {'MOBADC-W', 'PA-MOBADC', 'INDI-DE'}
%
%  The codes (L0-L3, V, iii, iii-0, H3, ...) stay in result files and runners; no figure, table or manuscript
%  shows them (tools/check_names.py). An unknown code is returned unchanged, so the check catches it.
M = {'Classical', 'PID';  'Classical+trim', 'PID + trim';  'DO+trim', 'DO + trim';  'DO', 'DO';  'ESO', 'ESO';
     'MOBADC', 'MOBADC';  'L0', 'MOBADC';  'L1', 'MOBADC-DC';  'L2', 'MOBADC-W';  'V', 'MOBADC-W + preview';
     'L3', 'PA-MOBADC';  'L3(D2)', 'PA-MOBADC';  'L3_iii0', 'PAW-MOBADC';  'L3_iii', 'MBP';  'H3', 'INDI-DE';
     'L3_iii0_k070', 'PAW-MOBADC (K-hat x 0.7)';  'L3_iii0_k130', 'PAW-MOBADC (K-hat x 1.3)';
     'L3_iii0_s070', 'PAW-MOBADC (factor x 0.7)';  'L3_iii0_s130', 'PAW-MOBADC (factor x 1.3)';
     'H3_b086', 'INDI-DE (bias 0.086)';  'H3_b170', 'INDI-DE (bias 0.17)';
     'O', 'oracle';  'P', 'PI-MoE';  'O0', 'oracle (0 ms)';  'O150', 'oracle (150 ms)';
     'L3_6', 'PA-MOBADC + N6 term';  'P_6', 'PI-MoE + N6 term';  'O_6', 'oracle + N6 term';
     'O6_0', 'oracle (0 ms) + N6 term'};
one = ischar(in);
if one, in = {in}; end
out = in;
for k = 1:numel(in)
    j = find(strcmp(M(:, 1), in{k}), 1);
    if ~isempty(j), out{k} = M{j, 2}; end
end
if one, out = out{1}; end
end
