% Speech Recognition Using Cross-Correlation in MATLAB

% Step 1: Record and save template words as 'one.wav', 'two.wav', etc.

% Step 2: Preprocess Audio
% Load the input word for recognition
[inputSignal, inputFs] = audioread('./Test/test3.wav'); 
inputSignal = inputSignal / max(abs(inputSignal)); % Normalize input signal

% List of template audio files
templateDirectory = './Train/'; % Replace with your directory path
fileList = dir(fullfile(templateDirectory, '*.wav'));
templateFiles = fullfile({fileList.folder}, {fileList.name});


% Step 3: Preload templates (optional for efficiency)
templates = cell(1, length(templateFiles));
templateFsList = zeros(1, length(templateFiles));
for i = 1:length(templateFiles)
    [templateSignal, templateFs] = audioread(templateFiles{i});
    templates{i} = templateSignal / max(abs(templateSignal)); % Normalize template
    templateFsList(i) = templateFs;
end



recognizedWord = ''; % To store the recognized word
highestCorrelation = 0; % Initialize the highest correlation value

% Step 3-5: Cross-Correlation and Recognition Loop
for i = 1:length(templateFiles)
    % Load each template
    [templateSignal, templateFs] = audioread(templateFiles{i});
    templateSignal = templateSignal / max(abs(templateSignal)); % Normalize template
    
    % Check if sampling rates match
    % if inputFs ~= templateFs
    %     error('Sampling rates of input and template files do not match.');
    % end
    
    % Perform cross-correlation
    [corrValue, ~] = xcorr(inputSignal, templateSignal);
    maxCorr = max(abs(corrValue)); % Find the maximum correlation value
    
    % Update recognized word if correlation is higher than previous maximum
    if maxCorr > highestCorrelation
        highestCorrelation = maxCorr;
        recognizedWord = templateFiles{i}; % Store the best match
    end
end

% Step 4: Analyze the Results
if highestCorrelation > 0.7 % Example threshold for recognition
        % Extract only the file name and extension
    [~, recognizedFileName, recognizedFileExt] = fileparts(recognizedWord);
    fprintf('Recognized word: %s\n', recognizedFileName);
else
    fprintf('No word recognized. Adjust the threshold or improve recordings.\n');
end

% Step 6: Test and Tune
% - Test the system with various inputs.
% - Adjust the threshold in line 30 for better results.

