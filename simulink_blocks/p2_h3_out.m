function d_hat = p2_h3_out(s, prm)
%#codegen
%P2_H3_OUT  MATLAB Function block P2/P2_Core/P2/P2_H3_out (REGISTER_P2 sec 40.1, sec 50.5; competitor H3).
%
%  The H3 estimate read from the filter STATE only: d_hat(a) = Cf x_a, x_a = s(2a:2a+1) - the same
%  arithmetic as the d_hat output of p2_h3_indi.m. A MATLAB Function block is direct feedthrough on every
%  input, so taking d_hat from P2_H3 (which also reads the thrust command f_cmd) closed an algebraic loop
%  position law -> thrust -> P2_H3 -> dmf_hat -> position law at the first H3 build; this block reads only the
%  Unit Delay H3_s and the parameters, so the loop is broken and the values are unchanged.
%
%  In   s    7x1 state at t (Unit Delay H3_s)
%       prm  11x1 core/p2_h3_prm.m
%  Out  d_hat 3x1
d_hat = zeros(3, 1);
Cf = reshape(prm(7:8), 1, 2);
for a = 1:3
    x = s(2 * a:2 * a + 1);
    d_hat(a) = Cf * x;
end
end
