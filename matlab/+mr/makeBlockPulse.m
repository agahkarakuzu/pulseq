function [rf, gz] = makeBlockPulse(flip,varargin)
%makeBlockPulse Create a block pulse with optional slice selectiveness.
%   rf=makeBlockPulse(flip, 'Duration', dur) Create block pulse
%   with given flip angle and duration.
%
%   rf=makeBlockPulse(flip, 'Bandwidth', bw) Create block pulse
%   with given flip angle and bandwidth (Hz). The duration is calculated as
%   1/(4*bw)
%
%   rf=makeBlockPulse(..., 'FreqOffset', f,'PhaseOffset',p)
%   Create block pulse with frequency offset and phase offset.
%
%   [rf, gz]=makeBlockPulse(...,'SliceThickness',st) Return the
%   corresponding slice select gradient suitable for MRI.
%
%   See also  Sequence.addBlock

persistent parser
if isempty(parser)
    parser = inputParser;
    parser.FunctionName = 'makeBlockPulse';
    
    % RF params
    addRequired(parser,'flipAngle',@isnumeric);
    addParamValue(parser,'duration',0,@isnumeric);
    addParamValue(parser,'freqOffset',0,@isnumeric);
    addParamValue(parser,'phaseOffset',0,@isnumeric);
    addParamValue(parser,'timeBwProduct',0,@isnumeric);
    addParamValue(parser,'bandwidth',0,@isnumeric);
    % Slice params
    addParamValue(parser,'maxGrad',0,@isnumeric);
    addParamValue(parser,'maxSlew',0,@isnumeric);
    parser.addOptional('gradOpts',mr.opts(),@isstruct);
    addParamValue(parser,'sliceThickness',0,@isnumeric);
end
parse(parser,flip,varargin{:});
opt = parser.Results;

if opt.duration==0
    if opt.timeBwProduct>0
        opt.duration = opt.timeBwProduct/opt.bandwidth;
    elseif opt.bandwidth>0
        opt.duration = 1/(4*opt.bandwidth);
    else
        error('Either bandwidth or duration must be defined');
    end
end

BW = 1/(4*opt.duration);
N=round(opt.duration/1e-6);
t = (1:N)*mr.Sequence.RfRasterTime;
signal=opt.flipAngle/(2*pi)/opt.duration*ones(size(t));

rf.type = 'rf';
rf.signal = signal;
rf.t = t;
rf.freqOffset = opt.freqOffset;
rf.phaseOffset = opt.phaseOffset;

if nargout>1
    assert(opt.sliceThickness>0,'SliceThickness must be provided');
    if opt.maxGrad>0
        opt.gradOpts.maxGrad = opt.maxGrad;
    end
    if opt.maxSlew>0
        opt.gradOpts.maxSlew = opt.maxSlew;
    end
    
    amplitude = BW/opt.sliceThickness;
    area = amplitude*opt.duration;
    gz = mr.makeTrapezoid('z','flatTime',opt.duration,'flatArea',area,opt.gradOpts);
    
    tFill = (1:round(gz.riseTime/1e-6))*1e-6;   % Round to microsecond
    rf.t = [tFill rf.t+tFill(end) tFill+rf.t(end)+tFill(end)];
    rf.signal=[zeros(size(tFill)), rf.signal, zeros(size(tFill))];
end
end