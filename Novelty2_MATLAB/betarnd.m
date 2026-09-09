function r = betarnd(a, b, varargin)
% BETARND - Pure base MATLAB implementation of betarnd
% Compatible replacement for Statistics and Machine Learning Toolbox function.
    if nargin < 3
        sz = [1, 1];
    elseif nargin == 3
        sz = varargin{1};
        if isscalar(sz), sz = [sz, sz]; end
    else
        sz = [varargin{:}];
    end
    
    n = prod(sz);
    r = zeros(n, 1);
    for k = 1:n
        ak = a(min(k, end));
        bk = b(min(k, end));
        ga = sample_gamma(ak);
        gb = sample_gamma(bk);
        if (ga + gb) > 0
            r(k) = ga / (ga + gb);
        else
            r(k) = ak / (ak + bk);
        end
    end
    r = reshape(r, sz);
end

function g = sample_gamma(alpha)
    if alpha < 1
        u = rand();
        g = sample_gamma_gt1(alpha + 1) * (u ^ (1 / alpha));
    else
        g = sample_gamma_gt1(alpha);
    end
end

function x = sample_gamma_gt1(a)
    d = a - 1/3;
    c = 1 / sqrt(9 * d);
    while true
        z = randn();
        v = (1 + c * z)^3;
        if v > 0
            u = rand();
            if u < 1 - 0.0331 * (z^4)
                x = d * v;
                return;
            end
            if log(u) < 0.5 * (z^2) + d * (1 - v + log(v))
                x = d * v;
                return;
            end
        end
    end
end
