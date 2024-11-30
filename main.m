% Speech Recognition Using Cross-Correlation in MATLAB

% Step 1: Record and save template words as 'one.wav', 'two.wav', etc.

% Step 2: Preprocess Audio
% Load the input word for recognition
[inputSignal, inputFs] = audioread('./Test/left.wav'); 
inputSignal = inputSignal / max(abs(inputSignal)); % Normalize input signal

% List of template audio files
templateDirectory = './templates/'; % Replace with your directory path
fileList = dir(fullfile(templateDirectory, '**', '*.wav'));
templateFiles = fullfile({fileList.folder}, {fileList.name});

% Step 3: Preload templates
if exist('templates.mat', 'file')
    fprintf('Preloading templates...\n');
    load('templates.mat');
else
    fprintf('Preloading templates...\n');
    % Preload and normalize templates as before
    save('templates.mat', 'templates', 'templateFsList');
end

% fprintf('Preloading templates...\n');
% templates = cell(1, length(templateFiles));
% templateFsList = zeros(1, length(templateFiles));
% for i = 1:length(templateFiles)
%     [templateSignal, templateFs] = audioread(templateFiles{i});
%     templates{i} = templateSignal / max(abs(templateSignal)); % Normalize template
%     templateFsList(i) = templateFs;
%
%     % Inform user about progress
%     if mod(i, 1000) == 0 || i == length(templateFiles)
%         fprintf('Loaded %d of %d templates...\n', i, length(templateFiles));
%     end
% end
% % Save templates and sampling rates to a .mat file
% save('templates.mat', 'templates', 'templateFsList');


% Ensure all templates have the same sampling rate as the input signal
if any(inputFs ~= templateFsList)
    error('Input and template audio files must have the same sampling rate.');
end

% Step 3-5: Cross-Correlation and Recognition Loop (Parallelized)
fprintf('Starting recognition...\n');
recognizedWord = ''; % To store the recognized word
highestCorrelation = 0; % Initialize the highest correlation value

% Pre-allocate an array to store correlation results
correlationResults = zeros(1, length(templateFiles));

% Use parallel processing to speed up the loop
parfor i = 1:length(templateFiles) % parfor instead of for for parallel execution
    templateSignal = templates{i};  % Use preloaded templates
    
    % Perform cross-correlation
    [corrValue, ~] = xcorr(inputSignal, templateSignal);
    correlationResults(i) = max(abs(corrValue)); % Store max correlation value for this template
end

% After the parallel loop, find the highest correlation
[highestCorrelation, bestMatchIndex] = max(correlationResults);
recognizedWord = templateFiles{bestMatchIndex};

% Step 4: Analyze the Results
if highestCorrelation > 0.7 % Example threshold for recognition
    [~, subdir, ~] = fileparts(fileparts(recognizedWord));
    fprintf('Recognized word: %s\n', subdir);
else
    fprintf('No word recognized. Adjust the threshold or improve recordings.\n');
end

% Step 6: Test and Tune
% - Test the system with various inputs.
% - Adjust the threshold in line 30 for better results.

