%% C-2 Run All below on cluster!

% load one of the logistics and overwrite some folders
cnmfefolder='X:\EmilyShijieShared_old\6922_moBatchVer\LogisticscnmfeBatchVer20170712.mat';
load(fullfile(cnmfefolder,LogisticscnmfeBatchVer20170712.mat));

% load motion corrected A's
load(fullfile(cnmfefolder,cnmfe_BatchVer_PartII_MotionCorrection.mat))

%% 0. Get cluster ready
if running_on_cluster % some procedures making cluster use robust
    [~, ~, ~] = maybe_spawn_workers(workersnum); 
    init_par_rng(2016);
end
%% 1. load samplelist,A and sample's File from ClusterI into cell for each day.
AandSample_list=dir(fullfile(cnmfefolder,'*PartI_Afinalsam*'));
Filesignal_list=dir(fullfile(cnmfefolder,'*PartI_File*'));

samplist_full_temp=cell(1,numel(sampleFilelist));
File_full_temp=cell(1,numel(sampleFilelist));
eachdayfilenum=[];

for i=1:numel(AandSample_list) %go through days
    File_temponeday=load(fullfile(cnmfefolder,Filesignal_list(i).name)); 
    AandSample_temponeday=load(fullfile(cnmfefolder,AandSample_list(i).name));     
    eachdayfilenum=[eachdayfilenum length(File_temponeday.File)];
    if i==1
        filelist_fulllist=AandSample_temponeday.samplelist;
        File_fulllist=File_temponeday.File;
    else
        filelist_fulllist=[filelist_fulllist AandSample_temponeday.samplelist];
        File_fulllist=[File_fulllist File_temponeday.File];
    end   
end
            daylength=length(eachdayfilenum); avefilenum=mean(eachdayfilenum);
every_file_num=floor(daylength^2/avefilenum);
choose_ind=mod(1:numel(filelist_fulllist),every_file_num)==1;
filelist_samplelist=filelist_fulllist(choose_ind);
File_samplelist=File_fulllist(choose_ind);

%%% Order similar neurons in the same sequence in each file, not necessary,
%%% but nice to do. It is fast.
M1=Over_Days_ResequenceAForMo(M,correlation_thresh,max2max2nd,skewnessthresh);

%% 2. Next, Use this A, in each file i, find C's corresponding to each A's found in file j.
eachfilenum_cumsum=cumsum(eachdayfilenum);
filenumsum = eachfilenum_cumsum(end);
ACS(filenumsum) = struct('Ain',[],'Cin',[],'STD',[]);  

S_L=length(eachfilenum_cumsum);

parfor i= 1:filenumsum % file
    Ain=[]; Cin=[]; STD=[];
    k=find((eachfilenum_cumsum>=i),1);
    for j=1:S_L % parfor needs this
        Aj=M1{k}{j};
        ACS_temp=A2C2A(File_fulllist(i), Aj, File_fulllist(i).options);
        Ain = [Ain ACS_temp.Ain]; Cin = [Cin; ACS_temp.Cin]; STD=[STD ACS_temp.STD];
    end
    ACS(i).Ain=Ain; ACS(i).Cin=Cin; ACS(i).STD=STD;
end
save([outputdir 'PartTwoOFcnmfeBatchVerMOTION.mat'],'-v7.3')
%% 3 Merge similar neurons
%%% Merge similar neurons based on spatial AND temporal correlation
%%%%%%%%%% use the highest correlation one!!!!
%m=cellfun(@(x) cat(2,x{:}), M, 'UniformOutput',false);
%%%%%%%%%%
Amask_temp=cat(2,M1{1}{:})>0;
%Amask_temp=bsxfun(@gt,Amask_temp,quantile(Amask_temp,0.3)); %only use central part for merging.
[Afinal,MC,newIDs,merged_ROIs] = mergeACforMo(Amask_temp,ACS,merge_thr_2);
% [size1,~]=cellfun(@size,newIDs);
% ACS(size1~=1)
save([outputdir 'commonAcnmfeBatchVerMOTION.mat'],'-v7.3')

%% 4.5 Determine Afinal that will be used to extract C's in each file.

%%% Some processes making Afinal nicer, modified from Pengcheng Zhou's
%%% idea.
for i=1:size(Afinal,2)
    ai=Afinal(:,i);
    temp = full(ai>quantile(ai, 0.5, 1));
    ai(~temp(:)) = 0;
    Afinal(:,i)=ai;
end

% Just in case some all zero A's got passed to this stage.
nz_ind=any(Afinal);
Afinal=Afinal(:,nz_ind);
newIDs=newIDs(nz_ind);


Apicname=sprintf('Day%.0fAfinal','16171819');
ColorAllNeurons(Afinal,File_full(1).options.d1,File_full(2).options.d2,Apicname,Aoutputdir);
eval(sprintf('save %sDay%.0fAfinalcnmfeBatchVerMotion %s', Aoutputdir,'16171819', 'Afinal'));
%% 5 "massive" procedure: Extract A from each file
neuron_batch(length(filelist_fulllist)) = struct('ind_del',[],'signal',[],'FileOrigin',[],'neuron',[]);

parfor i= 1:length(filelist_fulllist)  
    mode='massive';
    nam=fullfile(datadir,filelist(i).name);    
    [~,neuron_batch(i)]=demo_endoscope2(gSig,gSiz,min_corr,min_pnr,min_pixel,bd,FS,SSub,TSub,bg_neuron_ratio,nam,mode,[],Afinal,neuron_batch(i),convolveType,merge_thr);
    neuron_batch(i).FileOrigin=filelist_fulllist(i); % save origin(filelist)
end
fprintf('Massive extraction done.');
save([outputdir 'MassivecnmfeBatchVerMotion.mat'],'-v7.3')

%% 6 Partition between those neurons found in each file and those not. Save results.

parfor i= 1:length(filelist_fulllist)

    for j=1:size(neuron_batch(i).neuron.A,2)
        jA=neuron_batch(i).neuron.A(:,j);
        jC=neuron_batch(i).neuron.C(j,:);
        neuron_batch(i).signal(j,:)=median(jA(jA>0)*jC);
    end        
    fprintf('neuron_batch %.0f extraction done\n', i);
end

%% 5.5 deconvolve signal
[~, ~, ~, ~,neuron_batch]=PartTraces(neuron_batch);

%fprintf('First %.0f neurons are successfully deconvolved in each file while those after that are missing in some files\n', sum(~ind_del_final));
fprintf('ALL moBatchVer extractions done.\n');
eval(sprintf('save %sCNMFE_moBatchVer.mat %s -v7.3', outputdir, 'neuron_batch'));
fprintf('ALL moBatchVer data saved, check them out!');