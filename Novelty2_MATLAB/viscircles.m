function h = viscircles(centers, radii, varargin)
% VISCIRCLES - Pure base MATLAB implementation of viscircles
% Provides drop-in compatibility when Image Processing Toolbox is not installed.
    hold on;
    theta = linspace(0, 2*pi, 180);
    h = [];
    for k = 1:size(centers, 1)
        c = centers(k, :);
        r = radii(min(k, end));
        x = c(1) + r * cos(theta);
        y = c(2) + r * sin(theta);
        hp = plot(x, y, varargin{:});
        h = [h; hp]; %#ok<AGROW>
    end
end
