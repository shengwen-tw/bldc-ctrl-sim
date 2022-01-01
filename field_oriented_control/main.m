close all;

%===================%
% Simulator options %
%===================%

SIMULATION_TIME = 10; %[s], total time of the simulation
PWM_FREQ = 1000;      %[Hz], PWM frequency of the BLDC model
SVPWM_STEPS = 7;      %should not change (7-segment SVPWM)
ITERATION_TIMES = PWM_FREQ * SIMULATION_TIME * SVPWM_STEPS;

%============%
% Plot datas %
%============%

%3-phase currents
i_a = zeros(1, ITERATION_TIMES);
i_b = zeros(1, ITERATION_TIMES);
i_c = zeros(1, ITERATION_TIMES);

%motor speed
omega_m = zeros(1, ITERATION_TIMES);

%motor position
theta_r = zeros(1, ITERATION_TIMES);

%3-phase back EMF
e_a = zeros(1, ITERATION_TIMES);
e_b = zeros(1, ITERATION_TIMES);
e_c = zeros(1, ITERATION_TIMES);

%normalized 3-phase back EMF
f_a = zeros(1, ITERATION_TIMES);
f_b = zeros(1, ITERATION_TIMES);
f_c = zeros(1, ITERATION_TIMES);

%3-phase control voltages
v_a = zeros(1, 2*ITERATION_TIMES);
v_b = zeros(1, 2*ITERATION_TIMES);
v_c = zeros(1, 2*ITERATION_TIMES);

%time sequence
time_arr = zeros(1, ITERATION_TIMES);
pwm_time_arr = zeros(1, 2*ITERATION_TIMES);

%PI speed control
w_d = zeros(1, ITERATION_TIMES); %desited motor speed
T_d = zeros(1, ITERATION_TIMES); %desired torque

%ysteresis control parameters
i_d = zeros(1, ITERATION_TIMES);   %desited current
i_a_d = zeros(1, ITERATION_TIMES); %desired i_a current
i_b_d = zeros(1, ITERATION_TIMES); %desired i_b current
i_c_d = zeros(1, ITERATION_TIMES); %desired i_c current

%motor torque
torque = zeros(1, ITERATION_TIMES);

%clarke transformation
I_alpha = zeros(1, ITERATION_TIMES);
I_beta = zeros(1, ITERATION_TIMES);
I_gamma = zeros(1, ITERATION_TIMES);

%park transformation
I_q = zeros(1, ITERATION_TIMES);
I_d = zeros(1, ITERATION_TIMES);
I_z = zeros(1, ITERATION_TIMES);

%==============================%
% Process model and controller %
%==============================%

%process model
bldc = bldc_dynamics;
bldc = bldc.init(PWM_FREQ);

SVPWM_state = 1;
Uref = 100 / sqrt(3);
angle = 0;

%===========================%
% Id, Iq control parameters %
%===========================%

Id_d = 0; %desired Id current
Iq_d = 2; %desired Iq current
%
Kp_Idq = 5; %Kp gain of the Id and Iq controller
Ki_Idq = 1; %Ki gain of the Id and Iq controller
%
e_Id = 0;
e_Id_last = 0;
%
e_Iq = 0;
e_Iq_last = 0;
%
V_d = 0;
V_q = 0;
%
V_d_last = 0;
V_q_last = 0;

%======================%
% Simulation main loop %
%======================%

i = 1;
while i <= ITERATION_TIMES
    %apply clarke and park transformation on the current
    I_abc = [bldc.x(1); bldc.x(2); bldc.x(3)];
    I_alpha_beta_gamma = bldc.clarke_transform(I_abc);
    I_dqz = bldc.park_transform(I_alpha_beta_gamma, bldc.x(5));
    
    %main loop has 7 procedures to handle 7-segment SVPWM
    switch(SVPWM_state)
        case 1
            %dq current control
            e_Id = Id_d - I_dqz(1);
            e_Iq = Iq_d - I_dqz(2);
            V_d = V_d_last + (Kp_Idq * (e_Id - e_Id_last)) + (Ki_Idq * e_Id);
            V_q = V_q_last + (Kp_Idq * (e_Iq - e_Id_last)) + (Ki_Idq * e_Iq);
            V_d_last = V_d;
            V_q_last = V_q;
            
            %inverse park transformation of the voltage control signal
            V_dqz = [V_d; V_q; 0];
            V_alpha_beta_gamma = bldc.inv_park_transform(V_dqz, bldc.x(5));
            
            %convert the control signal from alpha-beta coordinate to the
            %space vector
            %TODO
            
            %generate test signal of Uref
            angle = angle + deg2rad(1);
            angle = mod(angle, 2*pi);
            
            %execute field-oriented control algorithm
            bldc = bldc.generate_SVPWM_signal(Uref, angle);
            
            %SVPWM output (1/7)
            bldc.u(1:3) = bldc.u_SVPWM(1, 1:3).';
            dt = bldc.T_SVPWM(1);
        case 2
            %SVPWM output (2/7)
            bldc.u(1:3) = bldc.u_SVPWM(2, 1:3).';
            dt = bldc.T_SVPWM(2);
        case 3
            %SVPWM output (3/7)
            bldc.u(1:3) = bldc.u_SVPWM(3, 1:3).';
            dt = bldc.T_SVPWM(3);
        case 4
            %SVPWM output (4/7)
            bldc.u(1:3) = bldc.u_SVPWM(4, 1:3).';
            dt = bldc.T_SVPWM(4);
        case 5
            %SVPWM output (5/7)
            bldc.u(1:3) = bldc.u_SVPWM(5, 1:3).';
            dt = bldc.T_SVPWM(5);
        case 6
            %SVPWM output (6/7)
            bldc.u(1:3) = bldc.u_SVPWM(6, 1:3).';
            dt = bldc.T_SVPWM(6);
        case 7
            %SVPWM output (7/7)
            bldc.u(1:3) = bldc.u_SVPWM(7, 1:3).';
            dt = bldc.T_SVPWM(7);
    end
    
    %disp(bldc.T_SVPWM);
    SVPWM_state = SVPWM_state + 1;
    
    %reset state to 1 after finished full 7-segment operation
    if(SVPWM_state > 7)
        SVPWM_state = 1;
    end
    
    %skip dt == 0 (happens if the desired space vector equals V1, V2, ..., V7)
    if(abs(dt) < 1e-6)
        continue;
    end
    
    %disp(SVPWM_state);
    %disp(dt);

    %update the BLDC dynamics
    bldc = bldc.update(dt);
        
    %============%
    % Plot datas %
    %============%
    
    %update time sequence
    if(i > 1)        
        time_arr(i) = time_arr(i - 1) + dt;       
    end
    
    %time sequence for control voltage
    pwm_time_arr(2*i-1) = time_arr(i); %time for expressing the control voltage from t-1 to t
    pwm_time_arr(2*i) = time_arr(i);   %time for expressing the control voltage from t to t+1
    
    %state variables
    i_a(i) = bldc.x(1); %current of phase A
    i_b(i) = bldc.x(2); %current of phase B
    i_c(i) = bldc.x(3); %current of phase C
    omega_m(i) = bldc.x(4); %motor speed
    theta_r(i) = bldc.x(5); %rotor position
    
    %control voltage from t-1 to t
    if i > 1
        v_a(2*i-1) = v_a(2*(i-1));
        v_b(2*i-1) = v_b(2*(i-1));
        v_c(2*i-1) = v_c(2*(i-1));
    end
    
    %control voltage from t to t+1
    v_a(2*i) = bldc.u(1);
    v_b(2*i) = bldc.u(2);
    v_c(2*i) = bldc.u(3);
    
    %back EMF
    e_a(i) = bldc.e(1);
    e_b(i) = bldc.e(2);
    e_c(i) = bldc.e(3);
    
    %normalized back EMF
    f_a(i) = bldc.f_a;
    f_b(i) = bldc.f_b;
    f_c(i) = bldc.f_c;
    
    %motor torque
    torque(i) = bldc.torque;
    
    %clarke transformation
    I_alpha(i) = I_alpha_beta_gamma(1);
    I_beta(i) = I_alpha_beta_gamma(2);
    I_gamma(i) = I_alpha_beta_gamma(3);
    
    %park transformation
    I_d(i) = I_dqz(1);
    I_q(i) = I_dqz(2);
    I_z(i) = I_dqz(3);
    
    %update iterator
    i = i + 1;
   end

figure('Name', 'Desired current');
plot(time_arr(:), i_d(:));
xlim([0 time_arr(end)]);
ylim([-20 50]);
xlabel('time [s]');
ylabel('i_d');

%3-phase back EMF
figure('Name', '3 phase currents');
subplot (3, 1, 1);
plot(time_arr(:), i_a(:), time_arr(:), i_a_d(:));
legend('Actual current', 'Desired current');
xlim([0 time_arr(end)]);
ylim([-5 5]);
xlabel('time [s]');
ylabel('i_a');
subplot (3, 1, 2);
plot(time_arr(:), i_b(:), time_arr(:), i_b_d(:));
legend('Actual current', 'Desired current');
xlim([0 time_arr(end)]);
ylim([-5 5]);
xlabel('time [s]');
ylabel('i_b');
subplot (3, 1, 3);
plot(time_arr(:), i_c(:), time_arr(:), i_c_d(:));
legend('Actual current', 'Desired current');
xlim([0 time_arr(end)]);
ylim([-5 5]);
xlabel('time [s]');
ylabel('i_c');

%control voltage
figure('Name', 'Control votage');
subplot (3, 1, 1);
plot(pwm_time_arr(:), v_a(:));
xlim([0 time_arr(end)]);
ylim([-110 110]);
xlabel('time [s]');
ylabel('v_a');
subplot (3, 1, 2);
plot(pwm_time_arr(:), v_b(:));
xlim([0 time_arr(end)]);
ylim([-110 110]);
xlabel('time [s]');
ylabel('v_b');
subplot (3, 1, 3);
plot(pwm_time_arr(:), v_c(:));
xlim([0 time_arr(end)]);
ylim([-110 110]);
xlabel('time [s]');
ylabel('v_c');

figure('Name', 'Motor speed');
plot(time_arr(:), 9.5493 .* omega_m(:), time_arr(:), 9.5493 .* w_d(:));
legend('Actual speed', 'Desired speed');
xlim([0 time_arr(end)]);
ylim([-20 200]);
xlabel('time [s]');
ylabel('\omega_m [RPM]');

figure('Name', 'Motor position');
plot(time_arr(:), rad2deg(theta_r(:)));
legend('Actual position');
xlim([0 time_arr(end)]);
ylim([-20 380]);
xlabel('time [s]');
ylabel('\theta_r');

%3-phase back EMF
figure('Name', 'Back EMF');
subplot (3, 1, 1);
plot(time_arr(:), e_a(:));
xlim([0 time_arr(end)]);
ylim([-5 5]);
xlabel('time [s]');
ylabel('e_a');
subplot (3, 1, 2);
plot(time_arr(:), e_b(:));
xlim([0 time_arr(end)]);
ylim([-5 5]);
xlabel('time [s]');
ylabel('e_b');
subplot (3, 1, 3);
plot(time_arr(:), e_c(:));
xlim([0 time_arr(end)]);
ylim([-5 5]);
xlabel('time [s]');
ylabel('e_c');

%3-phase normalized back EMF
figure('Name', 'Normalized back EMF');
subplot (3, 1, 1);
plot(time_arr(:), f_a(:));
xlim([0 time_arr(end)]);
ylim([-1.3 1.3]);
xlabel('time [s]');
ylabel('f_a');
subplot (3, 1, 2);
plot(time_arr(:), f_b(:));
xlim([0 time_arr(end)]);
ylim([-1.3 1.3]);
xlabel('time [s]');
ylabel('f_b');
subplot (3, 1, 3);
plot(time_arr(:), f_c(:));
xlim([0 time_arr(end)]);
ylim([-1.3 1.3]);
xlabel('time [s]');
ylabel('f_c');

figure('Name', 'Motor torque');
plot(time_arr(:), torque(:), time_arr(:), T_d);
legend('Actual torque', 'Desired torque');
xlim([0 time_arr(end)]);
ylim([-0.2, 0.5]);
xlabel('time [s]');
ylabel('\tau [Nm]');

%clarke transformation
figure('Name', 'Clarke Transformation of the current');
subplot (3, 1, 1);
plot(time_arr(:), V_alpha(:));
xlim([0 time_arr(end)]);
ylim([-5 5]);
xlabel('theta_r');
ylabel('I_{\alpha}');
subplot (3, 1, 2);
plot(time_arr(:), V_beta(:));
xlim([0 time_arr(end)]);
ylim([-5 5]);
xlabel('theta_r');
ylabel('I_{\beta}');
subplot (3, 1, 3);
plot(time_arr(:), V_gamma(:));
xlim([0 time_arr(end)]);
ylim([-5 5]);
xlabel('theta_r');
ylabel('I_{\gamma}');

%park transformation
figure('Name', 'Park Transformation of the current');
subplot (3, 1, 1);
plot(time_arr(:), I_d(:));
xlim([0 time_arr(end)]);
ylim([-10 10]);
xlabel('theta_r');
ylabel('I_d');
subplot (3, 1, 2);
plot(time_arr(:), I_q(:));
xlim([0 time_arr(end)]);
ylim([-10 10]);
xlabel('theta_r');
ylabel('I_q');
subplot (3, 1, 3);
plot(time_arr(:), I_z(:));
xlim([0 time_arr(end)]);
ylim([-10 10]);
xlabel('theta_r');
ylabel('I_z');