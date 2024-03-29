%% MiMB Chapter Usign modeling to (re)design synthetic circuits
% Example Code for Repressilator
% Giselle McCallum
% 02/07/2019

clear all; close all; plot_settings();

% Mass Action: 
% 0 --> m_i : f(p_i-1) = lambda_m * K^h / (K^h + P_i^h)
% m_i --> 0 : beta_m
% m_i --> P_i : lambda_p
% P_i --> 0 : P_i * beta_p

% Parameter Definitions (units): 
beta_p = 1; % protein elimination rate (setting to 1 sets time units into protein lifetimes - scale other rate values)(tau_p^-1)
beta_m = 0.1*(25/log(2)); % mRNA elimination rate constant (tau_p^-1)(assuming 25 min protein halflife) 

lambda_m = 4.1*(25/log(2)); % max transcription rate constant (mRNAs tau_p^-1)
lambda_p = 1.8*(25/log(2)); % translation rate constant (proteins mRNA^-1 tau_p^-1)

h = 2; % Hill coefficient of cooperativity
K = 7; % Repression threshold (1/2 of all repressors are bound)

% Solve/Simulate
% ODE model ---------------------------------------------------------------

p = [lambda_m, lambda_p, beta_m, beta_p, h, K]; % Parameter vector to hand to ODE solver

% Set initial conditions:
x0 = [10;0;0;0;0;0]; %[m1, P1, m2, P2, m3, P3] - cannot be symmetrical for deterministic system to oscillate

% Time vector:
t_span = 0:.1:1000;

% Call solver:
[t1,x1] = ode23s(@derivatives_repressilator,t_span,x0,[],p); % [time, copy number] = ode23s(odes, time vector, initial conditions, options(empty), and parameter vector)

% Stochastic Simulations --------------------------------------------------

% Stoichiometry matrix: M x N matrix, where M is number of
% species, N is number of reactions, value indicates change number of
% molecules if that reaction occurs
stoich_mat=[...         reactions: prod_m1, deg_m1, prod_P1, deg_P1, prod_m2, deg_m2, prod_P2, deg_P2, prod_m3, deg_m3,prod_P3, deg_P3; 
                        % Species:
    1 -1 0 0 0 0 0 0 0 0 0 0 ; %m1
    0 0 1 -1 0 0 0 0 0 0 0 0 ; %pf1
    0 0 0 0 1 -1 0 0 0 0 0 0 ; %m2
    0 0 0 0 0 0 1 -1 0 0 0 0 ; %pf2
    0 0 0 0 0 0 0 0 1 -1 0 0 ; %m3
    0 0 0 0 0 0 0 0 0 0 1 -1 ; %pf3
    ];

% Simulation settings
n = 1e6; % Number of iterations in Gillespie - should be long enough to characterize results

% Rate vector function
rvf= @(x)([lambda_m*K^h/(K^h+x(6)^h) (beta_m+beta_p)*x(1) lambda_p*x(1)  beta_p*x(2) ...
        lambda_m*K^h/(K^h+x(2)^h) (beta_m+beta_p)*x(3) lambda_p*x(3)  beta_p*x(4) ...
        lambda_m*K^h/(K^h+x(4)^h) (beta_m+beta_p)*x(5) lambda_p*x(5)  beta_p*x(6)]);

% Call Gillespie function    
[t2,x2,tau] = gillespie(x0,rvf,stoich_mat,n); % [time, copy number, tau leap] = gillespie(initial conditions, rate vector function, stoich matrix, number interations to run);
    

%%
% Plot results
figure('Renderer', 'painters', 'Position', [10 10 1200 700]) % set size of figure
hold on

sp1 =subplot(2,1,1);
h = plot(t1,x1(:,2:2:6)); % Plots protein copy number only, for mRNA, plot rows 1,3,5
xlim([0 100]);

l=legend('P1','P2','P3');
set(l,'location','northeast')
title('Deterministic Solution')
yl = ylabel('Copy Number');
set(yl,'Position',[-8 -8 -8]);
set(h, {'color'}, {[0.7882    0.2118    0.2118]; [0.9686    0.7333    0.1765]; [0.0039    0.3059    0.5686]});


sp2 = subplot(2,1,2);
h2=plot(t2,x2(1:2:5,:));
xlim([0 100]); xlabel('Time (\tau_P)')
title('Stochastic Simulation')
set(h2, {'color'}, {[0.7882    0.2118    0.2118]; [0.9686    0.7333    0.1765]; [0.0039    0.3059    0.5686]});


%% Calculate and plot autocorrelation

% Resample result matrix at regular time intervals - makes vector rt evenly space
t_resample = mean(tau); 
[rt,rx] = resample(t2,x2,t_resample); %[resampled time, copy number at new times] = resample(time vector from Gillespie, copy numbers from gillespie, resample interval )

ac = autocorrelation(rx); % Calculates autocorrelation of simulation time traces
[pks,locs] = findpeaks(ac(10:end)); % finds the first peak of the autocorrelation function - have to start a few time points in, or it finds the first peak at 0
if isempty(pks) == 1 % If there is no peak, there are no oscillations
    period = 0;
    precision = 0;
else
    period = rt(locs(1)); % period is the time value at the first peak in autocorrelation
    precision = pks(1); % precision is the autocorrelation value at the first peak
end

figure('Renderer', 'painters', 'Position', [10 10 800 700]) % set size of figure
hold on
plot(rt,ac,'linewidth',4);
scatter(rt(locs(1)),pks(1),200,'v','MarkerEdgeColor','k','MarkerfaceColor','r','LineWidth',2); % highlights first peak

str = {['period: ' num2str(round(period,2))]}; % Adds textbox with period
annotation('textbox',[0.6 0.7 0.3 0.3],'String',str,'FontSize',26,'FitBoxToText','on','horizontalalignment','center','verticalalignment','middle');

xlim([0 40]);

xlabel('Time (\Delta\tau_P)');
ylabel('Concentration ACF');


%% Functions - must be defined below the rest of the script

function dydt = derivatives_repressilator(t,y,p)
% Derivatives that get handed to numerical ODE solver
% Inputs: [time vector, y0 vector, parameter vector]

% p = [lambda_m, lambda_p, beta_m, beta_p, h, K]; % Parameter vector
% definition

dydt = [0;0;0;0;0;0]; %[m1; P1; m2; P2; m3; P3] initialize with zeros!
dydt (1) = p(1)*p(6)^p(5) / (p(6)^p(5)+y(6)^p(5)) - y(1)*(p(3)+p(4)); % m1
dydt (2) = y(1)*p(2) - y(2)*p(4); % P1
dydt (3) = p(1)*p(6)^p(5) / (p(6)^p(5)+y(2)^p(5)) - y(3)*(p(3)+p(4)); % m2
dydt (4) = y(3)*p(2) - y(4)*p(4); % P2
dydt (5) = p(1)*p(6)^p(5) / (p(6)^p(5)+y(4)^p(5)) - y(5)*(p(3)+p(4)); %m3
dydt (6) = y(5)*p(2) - y(6)*p(4); % P3
end

%--------------------------------------------------------------------------

function [t,x,tau] = gillespie(x0,rvf,stoich_mat,n)
% Runs Gillespie Algorithm for n iterations
% Inputs: [column vector of initial conditions, rate vector function,
% stoichiometry matrix, number of iterations to perform];
% Outputs: [time vector, copy number of each species, vector of tau (interval size between rxns)]; 

% Set up matrices to store output data:
x = [x0, zeros(length(x0),n)]; % matrix to store x vals
t = zeros(1,n+1); % matrix to store times
tau = zeros(1,n); % matrix to store intervals between reactions

for i=1:n  
    %Calculate the total rate and pick the waiting time for the next reaction
    %event from an exponential distribution, with cumulative distribution
    %function F(t)=1-exp(-r*T)
    lambda = rvf(x(:,i)); % Calculates rates using current quantities of each species
    lambda_tot = sum(lambda); % Total of all reaction rates 
    T = -log(rand())/lambda_tot; % Calculate time to next reaction, T
    
    %Pick exactly one of the reactions, choosing reaction k with
    %probability p(k)/p(total)
    r = rand(); % Generate random number between [0 1]
    lambda = lambda/lambda_tot; % Normalize to total of all rates
    lambda = cumsum(lambda); % cumulative sum at each rate
    
    I=1;
    while lambda(I) < r
        I=I+1;
    end % loop runs until the cumulative sum corresponding to the random number is reached - the index at this value tells us the reaction that occurs 
    
    % Update quantities, time vectors, tau vector
    t(i+1) = t(i)+T; % update time vector
    x(:,i+1) = x(:,i) + stoich_mat(:,I); % update current copy number of all proteins -> adds amount indicated in stoich matrix to the appropriate species
    tau (i) = T; % store time to reaction T in tau vector
end
end

%--------------------------------------------------------------------------

function [rt,rx] = resample(t,x,t_re)

rt = (0:floor(t(end)/t_re)-1)*t_re; % make new time vector, evenly spaced every t_re time points
rx = zeros(size(x,1),length(rt));

rx(:,1) = x(:,1); %initial conditions

% count through t, when t is just below rt(i), record this value as
% rx(i), then start counting through t again until you reach rt(i+1):
I = 1;
for i=2:length(rt)
    while t(I) < rt(i)
        I=I+1;
    end
    rx(:,i) = x(:,I-1);  
end

end

%--------------------------------------------------------------------------
function [ac] = autocorrelation(rx)
% Function to calculate autocorrelation of a time-trace
% Inputs: resampled data matrix ;
% Outputs: autocorrelation vector;

ac = zeros(1,size(rx,2)*2); % make vector to store autocorrelation
rx = rx-mean(rx(:)); % centre data around 0
n = size(rx,1);

for i=1:n % for each species
    frx = fft(rx(i,:),length(ac)); % calculate ac for a species using discrete Fourier transform
    ac = ac + ifft(frx.*conj(frx)); % convolution theorem; add autocorrelation for each time trace 
end

ac = ac/n; % average for all time traces;
ac = fftshift(ac); % swap left and right so its easier to normalize
ac = ac./[1 1:size(rx,2) size(rx,2)-1:-1:1]/std(rx(:))^2; % divide by the number points summed for each lag, then normalize with variance
ac = fftshift(ac); % swap sides again to make it easier to plot
ac = ac(1:length(ac)/2); % only output the first half

end
%--------------------------------------------------------------------------

function []=plot_settings()
% Changes Default Plot settings - not necessary, just for aesthetics!
set(0,'DefaultAxesFontSize',15,...
'DefaultLegendFontSize',15,'DefaultLegendFontSizeMode','manual',...
'DefaultAxesBox','on',...
'DefaultLineLineWidth',2.5,...
'DefaultAxesXColor',[0 0 0],...
'DefaultAxesYColor',[0 0 0],...
'DefaultAxesZColor',[0 0 0],...
'DefaultTextFontname','Arial',...
'DefaultAxesLineWidth',1.5,...
'DefaultAxesFontSize',24,...
'DefaultAxesGridColor','k',...
'DefaultAxesGridAlpha',0.25,...
'DefaultAxesFontname','Arial',...
'DefaultFigureColor',[1 1 1],...
'DefaultAxesTitleFontWeight', 'normal', ...
'DefaultAxesTitleFontSizeMultiplier', 1.25) ;
end


