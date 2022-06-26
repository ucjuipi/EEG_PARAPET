%naming
FOLDER = 'C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_TRIAL';
DATASETS = 'C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_DATASETS';
ICA = 'C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_ICA';
ERPDATASETS = 'C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_ERP';
LOWCUT = 0.5;
HIGHCUT = 50;
SAMPLER = 512;
EPOCHBEF = -200.0;
EPOCHAFT = 1000.0; %maybe 2000 if needed
EVENTLIST = 'C:\Users\inesa\OneDrive\Desktop\EEG_DATA\PARAPET_process\EventList.txt';
BINDESC = 'C:\Users\inesa\OneDrive\Desktop\EEG_DATA\PARAPET_process\bindescrip.txt';
ERPLOW = 30;
ERPBINCHOC = 'bin5 = bin2 - bin1 label Chocolate CS+ CS- difference'
ERPBINNOT = 'bin6 = bin4 - bin3 label Nothing CS+ CS- difference'

%open eeglab
eeglab 

% Get list of files
filesEEG = dir(FOLDER);

%amount of files in folder
nFiles = length(filesEEG);
filesEEG = filesEEG(3:nFiles);
nFiles = length(filesEEG);
filesEEG(1).name

for pp = 1:nFiles  % will be able to run through multiple participants e.g. 1:90 or to nfiles for all
    try
    ero = 'load error';   %set as different things throughout so we can see where the script stopped at for that pps to figure out what's going wrong      
    EEG = pop_loadeep_v4(sprintf(strcat(FOLDER,'/%s'),  filesEEG(pp).name));

    %cuts data before/after first/last relevant event
    Eventt = {EEG.event(:).type}; 
    ero = 'cut error';
    eventIndexes = [find(strcmp(Eventt, '20')), find(strcmp(Eventt, '30')), find(strcmp(Eventt, '35')), find(strcmp(Eventt, '40')), find(strcmp(Eventt, '50')), find(strcmp(Eventt, '60')), find(strcmp(Eventt, '70'))];
    eventIndexes = sort(eventIndexes); %usually in order anyway
    TimeOfFirstEvent = (((EEG.event(min(eventIndexes(:))).latency)/1000))-60;  
    TimeOfLastEvent = (((EEG.event(max(eventIndexes(:))).latency)/1000))+60;
    AcqTrials=length(eventIndexes);

    EEG = pop_select(EEG,'time',[TimeOfFirstEvent TimeOfLastEvent]);
    EEG = eeg_checkset(EEG);


    %% pre-processing starts
    EEG.etc.eeglabvers = '2022.0'; % this tracks which version of EEGLAB is being used, you may ignore it
    EEG = eeg_checkset(EEG);

    %update channel locations
    EEG=pop_chanedit(EEG, 'lookup','Standard-10-5-Cap385.sfp');
    EEG = eeg_checkset(EEG);

    %rereference data to average
    EEG = pop_reref(EEG, []);
    EEG = eeg_checkset(EEG);

    %highpass and lowpass filter 0.5 50
    EEG = pop_eegfiltnew(EEG, 'locutoff', LOWCUT,'hicutoff', HIGHCUT,'plotfreqz',1);
    EEG = eeg_checkset(EEG);

    %resample data to 512Hz
    EEG = pop_resample(EEG, SAMPLER);
    EEG = eeg_checkset(EEG);

    %clean raw data removes bad channels and then interpolate
    %remove bad channels
    EEG = pop_clean_rawdata(EEG, 'FlatlineCriterion',5,'ChannelCriterion',0.8,'LineNoiseCriterion',4,'Highpass','off','BurstCriterion',20,'WindowCriterion',0.25,'BurstRejection','on','Distance','Euclidian','WindowCriterionTolerances',[-Inf 7] );
    EEG = eeg_checkset(EEG);

    %save channels - use for notes
%    ChanR = 0;
%    channelsAfterRemove = [];
%    for ii = 1 : length(EEG.chanlocs)
%        ChanR = ChanR + 1;
%        channelsAfterRemove = [channelsAfterRemove, string([' ' EEG.chanlocs(ChanR).labels ' ']) ];
%    end

    %removed channel interpolation
    EEG = pop_interp(EEG, originalEEG.chanlocs, 'spherical');
    EEG = eeg_checkset( EEG );

    EEG = pop_saveset(EEG, sprintf('PAPAPET_%d_S1_PREPROC',pp), DATASETS);
    EEG = eeg_checkset(EEG);

    [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, EEG); %store the EEG dataset in ALLEEG variable (array of all datasets)
    end
end

%% delete useless files from DATASETS

% Get list of files
filesEEGPRE = dir(DATASETS);

%amount of files in folder
nFilesPRE = length(filesEEGPRE);
filesEEGPRE = filesEEGPRE(3:nFilesPRE);
nFilesPRE = length(filesEEGPRE);

%% ICA
%change number according to dataset to be processed
for pp = 1:nFilesPRE
    try
    ero = 'load error';   %set as different things throughout so we can see where the script stopped at for that pps to figure out what's going wrong      
    EEG = pop_loadeep_v4(sprintf(strcat(DATASETS,'/%s'),  filesEEGPRE(pp).name));

    EEG = pop_runica(EEG, 'icatype', 'runica', 'extended',1,'interrupt','on');
    EEG = eeg_checkset(EEG);
    pop_eegplot(EEG, 1, 0, 1);
    pop_selectcomps(EEG, [1:20]);
    EEG = eeg_checkset(EEG);
    
    %choose artifact components here in pop-up window
    
    %save in new datafile
    EEG = pop_saveset(EEG, sprintf('PAPAPET_%d_S1_ICA',pp), ICA)
    EEG = eeg_checkset(EEG);
    catch
    end
end

%% delete useless files from ICA

% Get list of files
filesEEGICA = dir(ICA);

%amount of files in folder
nFilesICA = length(filesEEGICA);
filesEEGICA = filesEEGICA(3:nFilesICA);
nFilesICA = length(filesEEGICA);

%% ERP - epoch, binlister, ERPSets
for pp = 1:nFilesICA
    try
    ero = 'load error';   %set as different things throughout so we can see where the script stopped at for that pps to figure out what's going wrong      
    EEG = pop_loadeep_v4(sprintf(strcat(ICA,'/%s'),  filesEEGICA(pp).name));

    %epoch segmentation
    % event list for ERPlab
    EEG = pop_overwritevent( EEG, 'code');
    EEG = pop_importeegeventlist(EEG, EVENTLIST , 'ReplaceEventList', 'on'); % GUI: 20-Jun-2022 10:00:47
    EEG = eeg_checkset(EEG);

    %bins  
    EEG  = pop_binlister(EEG , 'BDF', BINDESC, 'ExportEL', sprintf('C:\Users\inesa\OneDrive\Desktop\EEG_DATA\PARAPET_process\PARAPET_%d_S1_EventList.txt', pp), 'ImportEL', sprintf('C:\Users\inesa\OneDrive\Desktop\EEG_DATA\PARAPET_process\PARAPET_%d_S1_EventList.txt', pp), 'IndexEL',  1, 'SendEL2', 'EEG&Text', 'Voutput', 'EEG'); % GUI: 20-Jun-2022 10:03:36
    EEG = eeg_checkset(EEG);

    % epoch
    EEG = pop_epochbin(EEG, [EPOCHBEF  EPOCHAFT],  'pre');
    EEG = eeg_checkset(EEG);

    %artifact detection, subjects with >25% of epochs rejected will be removed
    %get amount of epochs before rejection
    trialsBefore = length(EEG.epoch);

    %artifact rejection
    EEG  = pop_artmwppth( EEG , 'Channel',  1:length(EEG.chanlocs), 'Flag',  1, 'LowPass',  -1, 'Threshold',  100, 'Twindow', [ -200 1000], 'Windowsize',  200, 'Windowstep',  100 ); % GUI: 21-Jun-2022 14:32:02
    EEG = eeg_checkset( EEG );
    %pop_eegplot( EEG, 1, 1, 1);

    % get amount of epochs after rejection
    trialsAfter = length(EEG.epoch);

    %calculate percentage of epochs rejected
    epochreject = (trialsBefore-trialsAfter)/trialsBefore
    %removes participant if >25% of epochs rejected
    if epochreject>0.25
        %% input to table of notes
    end

    %% CHECK IF THIS IS CORRECT, there is baseline correction auto during epoching I think...
    % pop_eegplot( EEG, 1, 1, 1);
    %EEG = pop_rmbase(EEG, [],[]);
    %EEG = eeg_checkset(EEG);

    %averaging the data - and get ERPsets
    ERP = pop_averager(ALLEEG , 'Criterion', 'good', 'DQ_custom_wins', 0, 'DQ_flag', 1, 'DQ_preavg_txt', 0, 'DSindex', 9, 'ExcludeBoundary','on', 'SEM', 'on' );
    ERP = pop_savemyerp(ERP, 'erpname', sprintf('PAPAPET_%d_S1_ERP.erp',pp), 'filename', sprintf('PAPAPET_%d_S1_ERP.erp',pp), 'filepath', DATASETS, 'Warning', 'on');

    %filter ERP
    ERP = pop_filterp(ERP,  1:length(EEG.chanlocs) , 'Cutoff',  ERPLOW, 'Design', 'butter', 'Filter', 'lowpass', 'Order',  2);

    % bin operations
    %% CHANGE BIN OPERATIONS TO ACCOUNT FOR length(EEG.chanlocs) -- perhaps %d, length(EEG.chanlocs)?
    ERP = pop_binoperator(ERP, {ERPBINCHOC, ERPBINNOT});
    ERP = pop_erpchanoperator(ERP, {'nch1 = ch1 - ( avgchan( 1:57) ) Label Fp1',  'nch2 = ch2 - ( avgchan( 1:57) ) Label Fpz', 'nch3 = ch3 - ( avgchan( 1:57) ) Label Fp2',  'nch4 = ch4 - ( avgchan( 1:57) ) Label F7',  'nch5 = ch5 - ( avgchan( 1:57) ) Label F4', 'nch6 = ch6 - ( avgchan( 1:57) ) Label F8',  'nch7 = ch7 - ( avgchan( 1:57) ) Label FC5',  'nch8 = ch8 - ( avgchan( 1:57) ) Label FC1', 'nch9 = ch9 - ( avgchan( 1:57) ) Label FC2',  'nch10 = ch10 - ( avgchan( 1:57) ) Label FC6',  'nch11 = ch11 - ( avgchan( 1:57) ) Label M1', 'nch12 = ch12 - ( avgchan( 1:57) ) Label T7',  'nch13 = ch13 - ( avgchan( 1:57) ) Label C3',  'nch14 = ch14 - ( avgchan( 1:57) ) Label Cz', 'nch15 = ch15 - ( avgchan( 1:57) ) Label C4',  'nch16 = ch16 - ( avgchan( 1:57) ) Label T8',  'nch17 = ch17 - ( avgchan( 1:57) ) Label M2', 'nch18 = ch18 - ( avgchan( 1:57) ) Label CP5',  'nch19 = ch19 - ( avgchan( 1:57) ) Label CP1',  'nch20 = ch20 - ( avgchan( 1:57) ) Label CP2', 'nch21 = ch21 - ( avgchan( 1:57) ) Label CP6',  'nch22 = ch22 - ( avgchan( 1:57) ) Label P7',  'nch23 = ch23 - ( avgchan( 1:57) ) Label P3', 'nch24 = ch24 - ( avgchan( 1:57) ) Label Pz',  'nch25 = ch25 - ( avgchan( 1:57) ) Label P4',  'nch26 = ch26 - ( avgchan( 1:57) ) Label P8', 'nch27 = ch27 - ( avgchan( 1:57) ) Label POz',  'nch28 = ch28 - ( avgchan( 1:57) ) Label O1',  'nch29 = ch29 - ( avgchan( 1:57) ) Label O2', 'nch30 = ch30 - ( avgchan( 1:57) ) Label AF7',  'nch31 = ch31 - ( avgchan( 1:57) ) Label AF8',  'nch32 = ch32 - ( avgchan( 1:57) ) Label F5', 'nch33 = ch33 - ( avgchan( 1:57) ) Label F6',  'nch34 = ch34 - ( avgchan( 1:57) ) Label FC3',  'nch35 = ch35 - ( avgchan( 1:57) ) Label FCz', 'nch36 = ch36 - ( avgchan( 1:57) ) Label FC4',  'nch37 = ch37 - ( avgchan( 1:57) ) Label C5',  'nch38 = ch38 - ( avgchan( 1:57) ) Label C1', 'nch39 = ch39 - ( avgchan( 1:57) ) Label C2',  'nch40 = ch40 - ( avgchan( 1:57) ) Label C6',  'nch41 = ch41 - ( avgchan( 1:57) ) Label CP3', 'nch42 = ch42 - ( avgchan( 1:57) ) Label CP4',  'nch43 = ch43 - ( avgchan( 1:57) ) Label P5',  'nch44 = ch44 - ( avgchan( 1:57) ) Label P1', 'nch45 = ch45 - ( avgchan( 1:57) ) Label P2',  'nch46 = ch46 - ( avgchan( 1:57) ) Label P6',  'nch47 = ch47 - ( avgchan( 1:57) ) Label PO5', 'nch48 = ch48 - ( avgchan( 1:57) ) Label PO3',  'nch49 = ch49 - ( avgchan( 1:57) ) Label PO4',  'nch50 = ch50 - ( avgchan( 1:57) ) Label PO6', 'nch51 = ch51 - ( avgchan( 1:57) ) Label FT7',  'nch52 = ch52 - ( avgchan( 1:57) ) Label FT8',  'nch53 = ch53 - ( avgchan( 1:57) ) Label TP7', 'nch54 = ch54 - ( avgchan( 1:57) ) Label TP8',  'nch55 = ch55 - ( avgchan( 1:57) ) Label PO7',  'nch56 = ch56 - ( avgchan( 1:57) ) Label PO8', 'nch57 = ch57 - ( avgchan( 1:57) ) Label Oz'} , 'ErrorMsg', 'popup', 'KeepLocations',  1, 'Warning', 'on');
    
    EEG = pop_saveset(EEG, sprintf('PAPAPET_%d_S1_ERP_FINAL',pp), ERPDATASETS);
    EEG = eeg_checkset(EEG);
    catch
    end
end





%% Notes
notes = matfile('C:\Users\inesa\OneDrive\Desktop\EEG_DATA\PARAPET_process\Notes.m','Writable', true);
notes.notes(1,1) = cellstr('ppNum');
notes.notes(1,2) = cellstr('Channels Rejected');
notes.notes(1,3)= cellstr('Epoch removed'); 
notes.notes(1,4) = cellstr('Percent removed');
notes.notes(1,5) = cellstr('Amount of event markers');
eventIndexes = 0;

notes.notes(pp+1,1) = cellstr(filesEEG(pp).name(1:n));
notes.notes(pp+1,2) = cellstr(length(channelsAfterRemove));
notes.notes(pp+1,3) = num2cell(trialsBefore - trialsAfter);
notes.notes(pp+1,4) = num2cell(((trialsAfter - trialsBefore)/ length(EEG.epoch))*100);
notes.notes(pp+1,5) = num2cell(length(eventIndexes));
