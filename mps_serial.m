%% MPS Handheld System Serial Tool
% ver 0.1 [01/06/2023]
% Written by Arturo di Girolamo
% University of Minnesota: Twin Cities | J.P Wang Group

%% Configurables:
data_folder = '~/Documents/my_mps_data'; % Set the path to your Data Folder Here.

baud_rate = 115200; % Current Serial Baud Rate, as defined in Device Firmware.
num_samples = 30000; % Number of 24b samples the device is currently set to collect.
manual_port = ""; % Populate this if you'd like to override auto-port-detect. YOU MUST USE THIS FOR WINDOWS.
bit_order = 1; % Set to 1 for Least Signifigant Sample first, or 0 for Most Signifigant Sample first.
reference_voltage = 4.096; % Set ADC Reference Voltage Here. (Typ. 4.096V)

%% How To Use The Script

welcome_message()

%% Automatic Port Detection

port_list = serialportlist; % Fetch all of the current ports & store in array.
[row,col] = size(port_list); % Obtain the size of the array of ports.
found_port = 0; % Define a Flag indicating if a port was auto-detected or not.

for N = 1:col % Loop through active ports.
    if contains(port_list(1,N), "/dev/cu.usbmodem") % Check if it matches the FTDI Cable Name.
        auto_port = port_list(1,N); % Set auto_port to matching port.
        found_port = 1; % Set Flag.
    end
end

if manual_port ~= "" % Check if a Manual Port was Defined (Highest Priority)
    selected_port = manual_port;
elseif found_port == 1 % If no Manual Port was Defined use Auto Port if found.
    selected_port = auto_port;
else % If no Port was defined or found we would like to Exit...
    info_log("No Port Detected, and No Manual Port Defined... Exiting...")
    return;
end

%% Open and Check our Serial Port

mps_device = serialport(selected_port,baud_rate); % Open the Serial Port
write(mps_device,"aa","string"); % Write 'aa' which should return AA to confirm connection.
return_value = read(mps_device, 1, "uint8"); % Read Back Response

if return_value == 170 % If the response was 0xaa, then we connected.
    info_log("Handheld MPS Device was Successfully Connected!")
else % If the response was not 0xaa then some error occured.
    info_log("Unable to connect to MPS Device... Exiting...")
    return;
end

%% Wait For User OK to Sample Data
% input() waits for RETURN to be pressed before continuing. 

% We do not care about dummy_string, which is whatever you entered before
% pressing return.

dummy_string = input("SerialTool is Ready to Collect a Sample. Press RETURN to Continue...");

%% Sample Data
% Steps to Collect a Data Sample:
% 1. Write '' to Start the ADC Sampling
% 2. Wait to Recieve '' which means the ADC has finished.
% 3. Write '' to tell the device you would like the samples sent.
% 4. Read Back N samples over the serial bus.
info_log("Sending Signal to begin ADC Sampling...")
write(mps_device,"bb","string"); % Write 'aa' which should return AA to confirm connection.
return_value = read(mps_device, 1, "uint8"); % Read Back Response
if return_value == 187 % Check response against 0xbb
    info_log("ADC Completed Sampling. Reading Back Data...")
else
    info_log("SerialTool timedout waiting for response from Device. Exiting...")
    return;
end
write(mps_device,"cc","string"); % Send Signal to Dump Data.
num_8bit_int = 3*num_samples; % Serial packets are sent in 8b chunks, so we need 3x the number of 24b samples recieved.
returned_data = read(mps_device, num_8bit_int, "uint8"); % Read back all the samples.


%% Post-Process Our Data

data_in_volts = convert_data_to_volts(returned_data, num_8bit_int, bit_order, reference_voltage);  % See Post-Process function for implementation. Converts 8b chuncks into voltage values.

%% Save Data
save_data(data_in_volts,data_folder); % data is saved in a binary format (*.mat) to be re-opened with matlab. Data is Time-Stamped.

%% Plot Data
plot_data(data_in_volts); % Show the Data for visual verification.

%% Function Defines
function info_log(msg) % Function to timestamp and output message to log.
     fprintf('[%s] %s \n', datestr(now), msg)
end

% Function that reconstructs our 24b samples and converts them into
% voltages.
function voltage_series = convert_data_to_volts(input_data, num_8bit_int_passed, bit_order, reference_voltage)
    every_third_8b_sample = 1 : 3 : num_8bit_int_passed;
    
    voltage_series = zeros(1,num_8bit_int_passed/3); % Pre-Allocate Array to size based on num samples.
    voltage_series = voltage_series.*(-1); % Set Array to negative one so it is clear if there is some error

    series_counter = 1; % Keep track of index in pre-allocated array.
    for sample_index = 1:length(every_third_8b_sample) % Loop Every third Sample because 3 8b values make up 1 24b value.
        if bit_order == 0
            reconstructed_24b_sample = input_data(sample_index+2) + 256*input_data(sample_index+1) + 65536*input_data(sample_index);
        elseif bit_order == 1
            reconstructed_24b_sample = input_data(sample_index) + 256*input_data(sample_index+1) + 65536*input_data(sample_index+2);
        end
        sample_in_volts = (reconstructed_24b_sample/16777215)*reference_voltage; % Divide by max value (0xFFFFFF) and multiply by reference.
        voltage_series(series_counter) = sample_in_volts; % Fill Current Index with calculated voltage
        series_counter = series_counter + 1; % Increment Counter 
    end
end

function plot_data(data_to_be_plotted)
    plot(data_to_be_plotted);
    legend('MPS Samples')
    xlabel('Sample'), ylabel('Voltage');
    title('Voltage Sampled by MPS Device')
end

function save_data(data_to_be_saved, data_folder)
    save(sprintf('%s/Collected_data_%s', data_folder,datestr(now)), 'data_to_be_saved');
end

% Function to Plot Welcome Message in Text Log
function welcome_message()
    disp("   __  ______  ____  ____        _      ________          __")
    disp("  /  |/  / _ \/ __/ / __/__ ____(_)__ _/ /_  __/__  ___  / /")
    disp(' / /|_/ / ___/\ \  _\ \/ -_) __/ / _ `/ / / / / _ \/ _ \/ / ')
    disp('/_/  /_/_/  /___/ /___/\__/_/ /_/\_,_/_/ /_/  \___/\___/_/ ')
    disp('University Of Minnesota | J.P. Wang Group | Version 0.1 ')
end