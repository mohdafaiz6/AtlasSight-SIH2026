function q = prctile(x, p)
% PRCTILE - Pure base MATLAB implementation of prctile
% Compatible replacement for Statistics and Machine Learning Toolbox function.
    x = x(~isnan(x));
    if isempty(x)
        q = NaN;
        return;
    end
    x = sort(x(:));
    N = length(x);
    if N == 1
        q = x(1);
        return;
    end
    idx = 1 + (N - 1) * (p / 100);
    i_low = max(floor(idx), 1);
    i_high = min(ceil(idx), N);
    weight = idx - i_low;
    q = (1 - weight) * x(i_low) + weight * x(i_high);
end
