classdef speech_recognition < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        TitleLabel                    matlab.ui.control.Label
        RecognizeButton               matlab.ui.control.Button
        LoadTemplateButton            matlab.ui.control.Button
        RecognizedWordTextBox         matlab.ui.control.EditField
        RecognizedWordEditFieldLabel  matlab.ui.control.Label
        AudioInput                    matlab.ui.control.EditField
        AudioInputEditFieldLabel      matlab.ui.control.Label
        SelectAudioButton             matlab.ui.control.Button
        ThresholdSlider               matlab.ui.control.Slider
        ThresholdLabel                matlab.ui.control.Label
        CurrentTemplateFolder         matlab.ui.control.EditField
        CurrentFolderLabel            matlab.ui.control.Label
        SelectFolderButton            matlab.ui.control.Button
        LogWindowPanel                matlab.ui.container.Panel
        LogWindow                     matlab.ui.control.TextArea
        Image                         matlab.ui.control.Image
    end

    
    properties (Access = private)
    TemplateFilePath % Stores the file path selected in selectTemplateButtonPushed
    TemplateFileName
    InputAudioFileName
    InputAudioFilePath
    InputSignal
    InputFs
    Data
    TemplateDirectory
    TemplateFiles

    end
    
    methods (Access = public)
        function appendTextToTextArea(app, textArea, newText)
            % Appends newText to the specified text area, or replaces the value if empty
            % Parameters:
            %   textArea: The text area component (e.g., app.TextArea)
            %   newText: The text to append (string or cell array of strings)
    
            existingText = textArea.Value; % Get the current text
    
            % Handle empty text area
            if isempty(existingText)
                if ischar(newText)
                    textArea.Value = {newText}; % Replace with new text
                else
                    textArea.Value = newText; % Assign directly if newText is already a cell array
                end
            else
                % Append to existing text
                if ischar(existingText)
                    existingText = {existingText}; % Convert to cell array
                end
                if ischar(newText)
                    newText = {newText}; % Ensure new text is in cell array format
                end
                textArea.Value = [existingText; newText]; % Append new text
            end
        end
    end
    
    methods (Access = private)
        function toggleRecognizeButton(app)
            fileName = app.InputAudioFileName;
            if ~isempty(fileName) && ~isempty(app.Data)
               app.RecognizeButton.Enable = true;
            else
               app.RecognizeButton.Enable = false;
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: SelectFolderButton
        function SelectFolderButtonPushed(app, event)
            f = figure('Renderer', 'painters', 'Position', [-100 -100 0 0]);
            folderPath = uigetdir("./templates/", "Select Templates Folder");
            delete(f);
            
            if folderPath ~= 0
                app.TemplateDirectory = folderPath;
                % Extract the last folder name from the full path
                [~, folderName, ~] = fileparts(folderPath);
    
               app.CurrentTemplateFolder.Value = folderName;
               if app.TemplateDirectory ~= 0
                   app.LoadTemplateButton.Enable = true;
               else
                   app.LoadTemplateButton.Enable = false;
               end

               
            else
                return
            end
        end

        % Button pushed function: LoadTemplateButton
        function LoadTemplateButtonPushed(app, event)
            app.appendTextToTextArea(app.LogWindow,'Preloading templates...');
            scroll(app.LogWindow,'bottom');
            drawnow;

            templateDirectory = app.TemplateDirectory;
            fileList = dir(fullfile(templateDirectory, '**', '*.wav'));
            templateFiles = fullfile({fileList.folder}, {fileList.name});
            app.TemplateFiles = templateFiles;
            if exist('templates.mat', 'file')
                data = load('templates.mat');
                app.Data = data;
                app.appendTextToTextArea(app.LogWindow,'Templates has been loaded successfully.');
                scroll(app.LogWindow,'bottom');
                drawnow;
            else
                app.appendTextToTextArea(app.LogWindow,'No templates found. Creating one...');
                scroll(app.LogWindow,'bottom');
                drawnow;
                % Preload and normalize templates as before
                templates = cell(1, length(templateFiles));
                templateFsList = zeros(1, length(templateFiles));
                 for i = 1:length(templateFiles)
                     [templateSignal, templateFs] = audioread(templateFiles{i});
                     templates{i} = templateSignal / max(abs(templateSignal)); % Normalize template
                     templateFsList(i) = templateFs;
                
                     % Inform user about progress
                     if mod(i, 1000) == 0 || i == length(templateFiles)
                         formattedText = sprintf('Loaded %d of %d templates...', i, length(templateFiles));
                         app.appendTextToTextArea(app.LogWindow,formattedText);
                         scroll(app.LogWindow,'bottom');
                         drawnow;
                         
                     end
                 end
                app.appendTextToTextArea(app.LogWindow,'Saving templates...');
                drawnow;
                save('templates.mat', 'templates', 'templateFsList');
                app.appendTextToTextArea(app.LogWindow,'Template Saved Successfully!');
                scroll(app.LogWindow,'bottom');
                drawnow;
            end
            toggleRecognizeButton(app);
        end

        % Button pushed function: SelectAudioButton
        function SelectAudioButtonPushed(app, event)
            f = figure('Renderer', 'painters', 'Position', [-100 -100 0 0]);
            [fileName, filePath] = uigetfile('*.wav', 'Select Input Audio', './Test/down.wav');
            delete(f);

            if isequal(fileName,0)
               return
            else
                inputAudio = fullfile(filePath, fileName);
                % Load the input word for recognition
                [inputSignal, inputFs] = audioread(inputAudio); 
                inputSignal = inputSignal / max(abs(inputSignal)); % Normalize input signal
                app.InputSignal = inputSignal;
                app.InputFs = inputFs;
    
                app.InputAudioFilePath = filePath;
                app.InputAudioFileName = fileName;
                app.AudioInput.Value = fileName;
                toggleRecognizeButton(app);
            end
        end

        % Button pushed function: RecognizeButton
        function RecognizeButtonPushed(app, event)
            app.RecognizedWordTextBox.Value = '';
            app.appendTextToTextArea(app.LogWindow,'Starting recognition...');
            drawnow;

            templateFiles = app.TemplateFiles;
            templates = app.Data.templates;
            inputSignal = app.InputSignal;
            audioThreshold = app.ThresholdSlider.Value * 0.01;

            recognizedWord = '';    % To store the recognized word
            highestCorrelation = 0; % Initialize the highest correlation value
            
            % Pre-allocate an array to store correlation results
            correlationResults = zeros(1, length(templateFiles));
            
            % Use parallel processing to speed up the loop
            q = parallel.pool.DataQueue;
            afterEach(q, @(data) app.appendTextToTextArea(app.LogWindow, data));
            
            parfor i = 1:length(templateFiles)
                templateSignal = templates{i};
                [corrValue, ~] = xcorr(inputSignal, templateSignal);
                correlationResults(i) = max(abs(corrValue));
            
                % Send progress updates
                if mod(i, 100) == 0 || i == length(templateFiles)
                    fText = sprintf('Compared %d of %d templates...', i, length(templateFiles));
                    send(q, fText); % Use DataQueue to send updates
                    drawnow;
                end
            end
            
            % After the parallel loop, find the highest correlation
            [highestCorrelation, bestMatchIndex] = max(correlationResults);
            recognizedWord = templateFiles{bestMatchIndex};

            thresholdPercentage = audioThreshold;
            if highestCorrelation >= thresholdPercentage
                [~, subdir, ~] = fileparts(fileparts(recognizedWord));
                app.RecognizedWordTextBox.Value = subdir;
                app.appendTextToTextArea(app.LogWindow, 'Speech recognition successful.');
                scroll(app.LogWindow,'bottom');
                drawnow;
                
            else
                app.appendTextToTextArea(app.LogWindow, 'No word recognized. Adjust the threshold or improve recordings.');
                scroll(app.LogWindow,'bottom');
                drawnow;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Color = [0.0392 0.0784 0.1176];
            app.UIFigure.Position = [100 100 699 582];
            app.UIFigure.Name = 'Speech Recognition App';
            app.UIFigure.Resize = 'off';

            % Create Image
            app.Image = uiimage(app.UIFigure);
            app.Image.ScaleMethod = 'fill';
            app.Image.Position = [3 4 681 535];
            app.Image.ImageSource = fullfile(pathToMLAPP, 'assets', 'SpeechBackground.png');

            % Create LogWindowPanel
            app.LogWindowPanel = uipanel(app.UIFigure);
            app.LogWindowPanel.ForegroundColor = [1 1 1];
            app.LogWindowPanel.BorderType = 'none';
            app.LogWindowPanel.TitlePosition = 'centertop';
            app.LogWindowPanel.Title = 'Log Window';
            app.LogWindowPanel.BackgroundColor = [0.051 0.149 0.2706];
            app.LogWindowPanel.FontName = 'Time';
            app.LogWindowPanel.Position = [57 54 562 147];

            % Create LogWindow
            app.LogWindow = uitextarea(app.LogWindowPanel);
            app.LogWindow.Editable = 'off';
            app.LogWindow.FontName = 'Time';
            app.LogWindow.FontColor = [1 1 1];
            app.LogWindow.BackgroundColor = [0.6784 0.7647 0.9686];
            app.LogWindow.Position = [1 -2 562 127];

            % Create SelectFolderButton
            app.SelectFolderButton = uibutton(app.UIFigure, 'push');
            app.SelectFolderButton.ButtonPushedFcn = createCallbackFcn(app, @SelectFolderButtonPushed, true);
            app.SelectFolderButton.Icon = fullfile(pathToMLAPP, 'assets', 'folder.png');
            app.SelectFolderButton.IconAlignment = 'right';
            app.SelectFolderButton.VerticalAlignment = 'bottom';
            app.SelectFolderButton.BackgroundColor = [0.0706 0.4902 0.702];
            app.SelectFolderButton.FontName = 'Roboto';
            app.SelectFolderButton.FontSize = 10;
            app.SelectFolderButton.FontColor = [1 1 1];
            app.SelectFolderButton.Position = [395 343 100 22];
            app.SelectFolderButton.Text = 'Select Folder';

            % Create CurrentFolderLabel
            app.CurrentFolderLabel = uilabel(app.UIFigure);
            app.CurrentFolderLabel.HorizontalAlignment = 'right';
            app.CurrentFolderLabel.FontName = 'time';
            app.CurrentFolderLabel.FontSize = 10;
            app.CurrentFolderLabel.FontColor = [0.4196 0.7882 0.8902];
            app.CurrentFolderLabel.Position = [51 343 176 22];
            app.CurrentFolderLabel.Text = 'Current Template Folder:';

            % Create CurrentTemplateFolder
            app.CurrentTemplateFolder = uieditfield(app.UIFigure, 'text');
            app.CurrentTemplateFolder.Tag = 'templateName';
            app.CurrentTemplateFolder.Editable = 'off';
            app.CurrentTemplateFolder.FontName = 'time';
            app.CurrentTemplateFolder.FontColor = [0.051 0.149 0.2706];
            app.CurrentTemplateFolder.Position = [242 343 127 22];

            % Create ThresholdLabel
            app.ThresholdLabel = uilabel(app.UIFigure);
            app.ThresholdLabel.HorizontalAlignment = 'right';
            app.ThresholdLabel.FontName = 'Time';
            app.ThresholdLabel.FontSize = 11;
            app.ThresholdLabel.FontColor = [0.5098 0.8235 0.9098];
            app.ThresholdLabel.Position = [51 309 99 22];
            app.ThresholdLabel.Text = 'Threshold: %';

            % Create ThresholdSlider
            app.ThresholdSlider = uislider(app.UIFigure);
            app.ThresholdSlider.FontName = 'Time';
            app.ThresholdSlider.FontSize = 11;
            app.ThresholdSlider.FontColor = [0.5098 0.8235 0.9098];
            app.ThresholdSlider.Tag = 'threshold';
            app.ThresholdSlider.Position = [171 318 445 3];
            app.ThresholdSlider.Value = 80;

            % Create SelectAudioButton
            app.SelectAudioButton = uibutton(app.UIFigure, 'push');
            app.SelectAudioButton.ButtonPushedFcn = createCallbackFcn(app, @SelectAudioButtonPushed, true);
            app.SelectAudioButton.Icon = fullfile(pathToMLAPP, 'assets', 'mic.png');
            app.SelectAudioButton.IconAlignment = 'right';
            app.SelectAudioButton.VerticalAlignment = 'bottom';
            app.SelectAudioButton.BackgroundColor = [0.0706 0.4902 0.702];
            app.SelectAudioButton.FontName = 'Roboto';
            app.SelectAudioButton.FontSize = 10;
            app.SelectAudioButton.FontColor = [1 1 1];
            app.SelectAudioButton.Position = [395 250 100 22];
            app.SelectAudioButton.Text = 'Select Audio';

            % Create AudioInputEditFieldLabel
            app.AudioInputEditFieldLabel = uilabel(app.UIFigure);
            app.AudioInputEditFieldLabel.HorizontalAlignment = 'right';
            app.AudioInputEditFieldLabel.FontName = 'Time';
            app.AudioInputEditFieldLabel.FontColor = [0.4196 0.7882 0.8902];
            app.AudioInputEditFieldLabel.Position = [51 250 100 22];
            app.AudioInputEditFieldLabel.Text = 'Audio Input:';

            % Create AudioInput
            app.AudioInput = uieditfield(app.UIFigure, 'text');
            app.AudioInput.Editable = 'off';
            app.AudioInput.FontName = 'Time';
            app.AudioInput.FontColor = [0.051 0.149 0.2706];
            app.AudioInput.Position = [242 250 127 22];

            % Create RecognizedWordEditFieldLabel
            app.RecognizedWordEditFieldLabel = uilabel(app.UIFigure);
            app.RecognizedWordEditFieldLabel.HorizontalAlignment = 'right';
            app.RecognizedWordEditFieldLabel.FontName = 'Time';
            app.RecognizedWordEditFieldLabel.FontSize = 14;
            app.RecognizedWordEditFieldLabel.FontColor = [0.6784 0.8902 1];
            app.RecognizedWordEditFieldLabel.Position = [57 21 164 22];
            app.RecognizedWordEditFieldLabel.Text = 'Recognized Word:';

            % Create RecognizedWordTextBox
            app.RecognizedWordTextBox = uieditfield(app.UIFigure, 'text');
            app.RecognizedWordTextBox.Editable = 'off';
            app.RecognizedWordTextBox.HorizontalAlignment = 'center';
            app.RecognizedWordTextBox.FontName = 'Time';
            app.RecognizedWordTextBox.FontWeight = 'bold';
            app.RecognizedWordTextBox.FontColor = [0.051 0.149 0.2706];
            app.RecognizedWordTextBox.Position = [236 21 354 22];

            % Create LoadTemplateButton
            app.LoadTemplateButton = uibutton(app.UIFigure, 'push');
            app.LoadTemplateButton.ButtonPushedFcn = createCallbackFcn(app, @LoadTemplateButtonPushed, true);
            app.LoadTemplateButton.BackgroundColor = [0.4196 0.7882 0.8902];
            app.LoadTemplateButton.FontName = 'time';
            app.LoadTemplateButton.FontSize = 9;
            app.LoadTemplateButton.FontWeight = 'bold';
            app.LoadTemplateButton.Enable = 'off';
            app.LoadTemplateButton.Position = [511 343 105 22];
            app.LoadTemplateButton.Text = 'Load Template';

            % Create RecognizeButton
            app.RecognizeButton = uibutton(app.UIFigure, 'push');
            app.RecognizeButton.ButtonPushedFcn = createCallbackFcn(app, @RecognizeButtonPushed, true);
            app.RecognizeButton.BackgroundColor = [0.6 0.9137 1];
            app.RecognizeButton.FontName = 'time';
            app.RecognizeButton.FontSize = 9;
            app.RecognizeButton.FontWeight = 'bold';
            app.RecognizeButton.Enable = 'off';
            app.RecognizeButton.Position = [511 250 110 22];
            app.RecognizeButton.Text = 'Recognize Audio';

            % Create TitleLabel
            app.TitleLabel = uilabel(app.UIFigure);
            app.TitleLabel.HorizontalAlignment = 'center';
            app.TitleLabel.VerticalAlignment = 'top';
            app.TitleLabel.FontName = 'Time';
            app.TitleLabel.FontSize = 24;
            app.TitleLabel.FontColor = [0.1804 0.5882 0.8];
            app.TitleLabel.Position = [1 488 675 51];
            app.TitleLabel.Text = 'Speech Recognition Application';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = speech_recognition

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end