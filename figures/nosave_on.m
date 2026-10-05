function tf = nosave_on()
%NOSAVE_ON  Read the VIEW-ONLY flag from the base workspace. Default OFF.
%
%   HOANG_NOSAVE = true;   fig2_validity   % draws, writes nothing
%   clear HOANG_NOSAVE                     % back to writing
%
%  The default must be OFF: forgetting to SET the flag still writes the files as
%  before, whereas a default of ON would make a real run silently write nothing
%  and nobody would notice until they went looking for the file.
%
%  This used to be a local function inside save_fig.m, which meant the flag only
%  worked for figures that called save_fig - and fig1..fig6 all call print()
%  directly. So "view only" silently wrote six PDFs and six PNGs. It is a shared
%  file now, and the fig_* scripts read it too.
tf = false;
try
    if evalin('base', 'exist(''HOANG_NOSAVE'',''var'')')
        tf = logical(evalin('base', 'HOANG_NOSAVE'));
    end
catch
end
end
