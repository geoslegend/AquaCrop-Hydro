% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This scripts handles all AquaCrop output. AquaCrop simulations are made
% outside matlab, using the Aquacrop software version 5.0. The type of software used to run simulations (nomal interface versus plugin)
% should be specified as input, as it affects the output format of AquaCrop files. Simulations are made for
% each landunit. This script will summarize the output of all landunits to
% come to one result for the whole catchment
%
% Author: Hanne Van Gaelen
% Last update: 12/11/2015
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [SimACOutput,CatchACOutput,SoilPar]= CatchmentOutput(DatapathAC, DatapathInput, ACMode)
      
%% %%%%%%%%%%%%%%%%%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 1. READ EXTRA INFORMATION ABOUT AQUACROP SIMULATION UNITS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%% 1.1 Select file with info on simulations
    name='SimInfo.txt';
    file = [DatapathInput name];        
    A= importdata(file); 
    clear name file
    
%%%% 1.2 Read all data of each simulation unit
    SimName=A.textdata(:,1);    % Name 
    SimNr=A.data(:,2);          % Numeric code of this simulation unit 
    SimType=A.data(:,3);        % Type of this simulation unit (1= other landuse (e.g forest, water, urban), 2= agricultural landuse, 999= no simulation)
    Clim=A.textdata(:,2);       % Climate 
    Soil=A.textdata(:,3);       % Soil type
    Crop=A.textdata(:,4);       % Crop type grown in main season
    CropAfter=A.textdata(:,5);  % Crop type grown after main season crop
    CropRot=A.textdata(:,6);    % Crop rotation (= main crop + after crop)
    SimArea=A.data(:,1);        % Relative area of this simulation unit in the catchment
    clear A
    
%%%% 1.3 Differentiate landunit types
    a=size(SimNr);
    nSim=a(1,1); % counts number of simulation units
    clear a;

    nAgrSim=0;          % counts number of agricultural simulation units
    nOtherSim=0;        % counts number of non-agricultural simulation units
    nNotSim=0;          % counts number of units for which no simulation was conducted
    AreatotAgrSim=0;    % counts total area of agricultural simulation units
    AreatotOtherSim=0;  % counts total area of non-agricultural simulation units
    AreatotNotSim=0;    % counts total area of non-simulated units
    
    for i=1:nSim % loop trough all simulation units
        if SimType(i,1)<900 
            if SimType(i,1)==2 % Agricultural landunits
            nAgrSim=nAgrSim+1;% Count
            AgrSim(nAgrSim,1)=SimNr(i,1);% Write Sim number
            AreatotAgrSim=AreatotAgrSim+SimArea(i,1); % Count area
            elseif SimType(i,1)==1  % Non-agricultural landunits
            nOtherSim=nOtherSim+1;  % Count
            OtherSim(nOtherSim,1)=SimNr(i,1);  % Write Sim number
            AreatotOtherSim=AreatotOtherSim+SimArea(i,1);% Count area
            end
        else % Non-simulated units
            nNotSim=nNotSim+1;
            NoRealSim(nNotSim,1)=SimNr(i,1);
            AreatotNotSim=AreatotNotSim+SimArea(i,1);
        end
    end
    
        RealSim=[AgrSim;OtherSim];% real simulation units = agricultural & non-agricultural
        nRealSim=nAgrSim+nOtherSim; 
        AreatotRealSim=AreatotAgrSim+AreatotOtherSim;
  

%%%% 1.4 Load soil characteristics
   % Load soil parameters of every soil type    
    name='SoilPar.txt';
    file = [DatapathInput name];        
    A= importdata(file); 
    clear name file

    SoilName=A.textdata(1,:);
    SoilPar=A.data(:,:);
    F=size(SoilName);
    nst=F(1,2); % number of soil types
    clear A F
        
   % Define soil parameters for every simulation unit
    for i =1:nSim % loop trough all simulation units
        st=1; %loop trough all soil types of parameter file
        for st=1:nst
            if strcmp(Soil(i,1),SoilName(1,st))==1
            SoilParSim(1:4,i)=SoilPar(1:4,st);% Write soil parameters
            st=nst; % break out of loop
            else
                %do nothing
            end    
        end
    end
    
  % Calculate soil parametes for catchment (=weighted average)
   for i=1:nSim % loop trough all landunits
   SoilParSimRel(1:4,i)=SoilParSim(1:4,i)*SimArea(i,:); 
   end  
   
   for i=1:4 % loop trough all soil parameters
   SoilPar2(i,1)=sum(SoilParSimRel(i,:))/100;
   end
   
   SoilPar=[SoilPar, SoilPar2]; % add results to soil parameters matrix
   
clear i st nst SoilPar2 SoilParSimRel

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 2. READ DAILY OUTPUT OF AQUACROP SIMULATIONS & REORGANIZE DATA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ACMode ==1 % AquaCrop was ran with the normal interface
    
    %%%% 2.1 Read output of AquaCrop for all simulations
    
        % Read daily crop output (*CROP.OUT) 
        CropOutput=ReadACCropOutput(DatapathAC);

        % Read daily water output (*Prof.OUT) 
        ProfOutput=ReadACProfOutput(DatapathAC);

        % Read daily water balance output (*WABAL.OUT) 
        WabalOutput=ReadACWabalOutput(DatapathAC);

    %%%% 2.2 Derive extra information 

        % Define the number of simulation units
        a=size(ProfOutput);
        nSimout=a(1,2);

        % Check if number of simulation units is correct
        if nRealSim==nSimout
            % do notting
        else
            error('number of simulation units does not match with number of output files');
        end 

        % Define the number of timesteps 
        a=size (ProfOutput{2,1});
        nTime=a(1,1);
        
    %%%% 2.3 Predefine variables
        WrTot=NaN(nTime,nRealSim); 
        WrZrx=NaN(nTime,nRealSim);
        Zr=NaN(nTime,nRealSim);
        RunNr=NaN(nTime,nRealSim);

        CC=NaN(nTime,nRealSim);
        B=NaN(nTime,nRealSim);
        Yseason=NaN(nTime,nRealSim);

        BundWat=NaN(nTime,nRealSim); 
        Tr=NaN(nTime,nRealSim); 
        Trx=NaN(nTime,nRealSim);
        E=NaN(nTime,nRealSim);
        Ex=NaN(nTime,nRealSim);
        ETa=NaN(nTime,nRealSim);
        ETx=NaN(nTime,nRealSim);
        RO=NaN(nTime,nRealSim);
        DP=NaN(nTime,nRealSim);
        CR=NaN(nTime,nRealSim);

        Day=NaN(nTime,nRealSim);
        Month=NaN(nTime,nRealSim);
        Year=NaN(nTime,nRealSim);

    %%%% 2.4 Fill up variables
        for i=1:nRealSim % Loop trough all real simulations for 

            Day(:,i)=ProfOutput{2,i} (:,2);
            Month(:,i)=ProfOutput{2,i} (:,3);
            Year(:,i)=ProfOutput{2,i} (:,4);

            RunNr(:,i)=ProfOutput{2,i} (:,1);
            WrTot (:,i)= ProfOutput{2,i}(:,7);
            WrZrx (:,i)= ProfOutput{2,i}(:,8);
            Zr(:,i)=ProfOutput{2,i}(:,9);

            CC(:,i)=CropOutput{2,i} (:,13);
            B(:,i)=CropOutput{2,i} (:,22);
            Yseason(:,i)=CropOutput{2,i} (:,24);

            BundWat(:,i)=WabalOutput{2,i} (:,10);
            Tr(:,i)=WabalOutput{2,i} (:,20);
            Trx(:,i)=WabalOutput{2,i} (:,19);
            E(:,i)=WabalOutput{2,i} (:,17);
            Ex(:,i)=WabalOutput{2,i} (:,16);
            ETa(:,i)=WabalOutput{2,i} (:,23);
            ETx(:,i)=WabalOutput{2,i} (:,22);
            RO(:,i)=WabalOutput{2,i} (:,12);
            DP(:,i)=WabalOutput{2,i} (:,13);
            CR(:,i)=WabalOutput{2,i} (:,14);

            M=max(RunNr(:,i)); 
            for k=1:M % Loop trough all individual runs of each sim unit
                cond=RunNr(:,i)==k;
                A=B(cond,i); % Select all values for simrun k
                C=Yseason(cond,i); 
                Bfin(k,i)=max(A); % Select the maximum of these values
                Y(k,i)=max(C);
            end

        end

 elseif ACMode ==2 % AquaCrop version 5.0 was ran with the plugin 
   %%%% 2.1 Read output of AquaCrop for all simulations
        % Read daily crop output (*day.OUT) 
            DayOutput=ReadACPlugDayOutput(DatapathAC);
        
   %%%% 2.2 Derive extra information 
        % Define the number of simulation units
        a=size(DayOutput);
        nSimout=a(1,2);

        % Check if number of simulation units is correct
        if nRealSim==nSimout
            % do notting
        else
            error('number of simulation units does not match with number of output files');
        end 

        % Define the number of timesteps 
        a=size (DayOutput{2,1});
        nTime=a(1,1);
        
    %%%% 2.3 Predefine variables
        WrTot=NaN(nTime,nRealSim); 
        WrZrx=NaN(nTime,nRealSim);
        Zr=NaN(nTime,nRealSim);
        RunNr=NaN(nTime,nRealSim);

        CC=NaN(nTime,nRealSim);
        B=NaN(nTime,nRealSim);
        Yseason=NaN(nTime,nRealSim);

        BundWat=NaN(nTime,nRealSim); 
        Tr=NaN(nTime,nRealSim); 
        Trx=NaN(nTime,nRealSim);
        E=NaN(nTime,nRealSim);
        Ex=NaN(nTime,nRealSim);
        ETa=NaN(nTime,nRealSim);
        ETx=NaN(nTime,nRealSim);
        RO=NaN(nTime,nRealSim);
        DP=NaN(nTime,nRealSim);
        CR=NaN(nTime,nRealSim);

        Day=NaN(nTime,nRealSim);
        Month=NaN(nTime,nRealSim);
        Year=NaN(nTime,nRealSim);
        
    %%%% 2.4 Fill up variables
        for i=1:nRealSim % Loop trough all real simulations for 

            Day(:,i)=DayOutput{2,i} (:,2);
            Month(:,i)=DayOutput{2,i} (:,3);
            Year(:,i)=DayOutput{2,i} (:,4);

            RunNr(:,i)=DayOutput{2,i} (:,1);
            WrTot (:,i)= DayOutput{2,i}(:,43);
            WrZrx (:,i)= DayOutput{2,i}(:,44);
            Zr(:,i)=DayOutput{2,i}(:,45);

            CC(:,i)=DayOutput{2,i} (:,31);
            B(:,i)=DayOutput{2,i} (:,38);
            Yseason(:,i)=DayOutput{2,i} (:,40);

            BundWat(:,i)=DayOutput{2,i} (:,10);
            Tr(:,i)=DayOutput{2,i} (:,20);
            Trx(:,i)=DayOutput{2,i} (:,19);
            E(:,i)=DayOutput{2,i} (:,17);
            Ex(:,i)=DayOutput{2,i} (:,16);
            ETa(:,i)=DayOutput{2,i} (:,23);
            ETx(:,i)=DayOutput{2,i} (:,22);
            RO(:,i)=DayOutput{2,i} (:,12);
            DP(:,i)=DayOutput{2,i} (:,13);
            CR(:,i)=DayOutput{2,i} (:,14);

            M=max(RunNr(:,i)); 
            for k=1:M % Loop trough all individual runs of each sim unit
                cond=RunNr(:,i)==k;
                A=B(cond,i); % Select all values for simrun k
                C=Yseason(cond,i); 
                Bfin(k,i)=max(A); % Select the maximum of these values
                Y(k,i)=max(C);
            end
        
        end
        
        
 end  
 clear a A C M Yseason WabalOutput CropOutput ProfOutput DayOutput;

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 3. CALCULATE SOIL WATER CONTENT IN 2 m SOIL DEPTH
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%% 3.1 Define the max rooting depth for every run in every sim unit
    
    % No automatic way of reading crop parameter Zrx (Zrx in output file can be affected by
    % water stress). In stead we use the Zrx values manually entered in the
    % textfile for every run of every sim unit

    name='Zrx.txt';
    file = [DatapathInput name];        
    Zrx= importdata(file); 

%%%% 3.2 Calculate the soil water content 

    for i=1:nRealSim; % Loop trough all simulation runs alle simulatie units                  
        
        M=max (RunNr(:,i)); % Determine the number of runnumber of each sim unit 
        timecount=0;  % Counts the timestep for the whole simulation period  
             
        for k=1:M % Loop trough all runs of that simulation unit
          Dout=2-Zrx(k,i);% depth outside rootzone                                               
          
          C=RunNr(RunNr(:,i)==k,i);%Determine the number of timesteps in RunNr
          a=size(C);
          nT=a(1,1);
                     
              for t=1:nT % Loop trough all timesteps of that runnumber
                timecount=timecount+1;  
                Wrin (timecount,i)=WrZrx(timecount,i);% calculate water content inside rootzone
                Wrout(timecount,i)=SoilParSim(1,i)*Dout; % calculate water content outside rootzone
                Wr2 (timecount,i)=Wrin(timecount,i)+Wrout(timecount,i); % calculate water content in 2 m depth                                          
              end  
                         
         end
        
    end
   
   clear name file t timecount  a C M i k nT

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 4. GENERATE OUTPUT FOR NON-SIMULATED UNITS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% This will only be done for water balance outputs and soil water content,
% it makes no sense to do this for crop output 

%%%% 4.1 Make list of agricultural sim numbers for each soil type
    nSiL=0; % counts all silt loam soils in agricultural landunits
    nSaL=0; % counts all sandy loam soils in agricultural landunits
    nSx=0; % counts all unknown soils in agricultural landunits

    for k=1:nAgrSim % loop trough all soils of agricultural landunit simulaties
        i=AgrSim(k,1);% Reads sim number
            if  strcmp(Soil(i,1),'SiL')==1
                nSiL=nSiL+1; % count 
                SiL(nSiL,1)=SimNr(i,1); % Write SimNr of this unit in the list of SiL numbers
            elseif strcmp(Soil(i,1),'SaL')==1
                nSaL=nSaL+1; 
                SaL(nSaL,1)=SimNr(i,1); % Write SimNr of this unit in the list of SaL numbers
            else
                nSx=nSx+1; 
                Sx(nSx,1)=SimNr(i,1); % Write SimNr of this unit in the list of unknown soil numbers
            end
    end

%%%% 4.2 Calculate relative contribution of each sim unit within the soil type 
    
    % Calculate total area of every soil type within the agricultural landunits
    AreaTotSiL=sum(SimArea(SiL,1));
    AreaTotSaL=sum(SimArea(SaL,1));

    % Calculate relative contributions
    for i=1:nSiL 
        Nr=SiL(i,1); % Loop trough all SaL sim numbers
        SimAreaRelSiL(i,1)=SimArea(Nr,1)/AreaTotSiL;
    end

    for i=1:nSaL 
        Nr=SaL(i,1); % Loop trough all SaL sim numbers
        SimAreaRelSaL(i,1)=SimArea(Nr,1)/AreaTotSaL;
    end

 %%%% 4.3 Calculate output values
 
    % Make subsets of each variable per soil type
     TrSaLNr=Tr(:,SaL);
     TrSiLNr=Tr(:,SiL);
     TrxSaLNr=Trx(:,SaL);
     TrxSiLNr=Trx(:,SiL);
     ESaLNr=E(:,SaL);
     ESiLNr=E(:,SiL);
     ExSaLNr=Ex(:,SaL);
     ExSiLNr=Ex(:,SiL);
     ETaSaLNr=ETa(:,SaL);
     ETaSiLNr=ETa(:,SiL);
     ETxSaLNr=ETx(:,SaL);
     ETxSiLNr=ETx(:,SiL);
     ROSaLNr=RO(:,SaL);
     ROSiLNr=RO(:,SiL);
     DPSaLNr=DP(:,SaL);
     DPSiLNr=DP(:,SiL);
     CRSaLNr=CR(:,SaL);
     CRSiLNr=CR(:,SiL);
     BundWatSaLNr=BundWat(:,SaL);
     BundWatSiLNr=BundWat(:,SiL);
     Wr2SaLNr=Wr2(:,SaL);
     Wr2SiLNr=Wr2(:,SiL);

    % Calculate weighted average 
     TrSaL=TrSaLNr*SimAreaRelSaL;
     TrSiL=TrSiLNr*SimAreaRelSiL;
     TrxSaL=TrxSaLNr*SimAreaRelSaL;
     TrxSiL=TrxSiLNr*SimAreaRelSiL;
     ESaL=ESaLNr*SimAreaRelSaL;
     ESiL=ESiLNr*SimAreaRelSiL;
     ExSaL=ExSaLNr*SimAreaRelSaL;
     ExSiL=ExSiLNr*SimAreaRelSiL;   
     ETaSaL=ETaSaLNr*SimAreaRelSaL;
     ETaSiL=ETaSiLNr*SimAreaRelSiL;
     ETxSaL=ETxSaLNr*SimAreaRelSaL;
     ETxSiL=ETxSiLNr*SimAreaRelSiL;
     ROSaL=ROSaLNr*SimAreaRelSaL;
     ROSiL=ROSiLNr*SimAreaRelSiL;
     DPSaL=DPSaLNr*SimAreaRelSaL;
     DPSiL=DPSiLNr*SimAreaRelSiL;
     CRSaL=CRSaLNr*SimAreaRelSaL;
     CRSiL=CRSiLNr*SimAreaRelSiL;
     BundWatSaL=BundWatSaLNr*SimAreaRelSaL;
     BundWatSiL=BundWatSiLNr*SimAreaRelSiL;
     Wr2SaL=Wr2SaLNr*SimAreaRelSaL;
     Wr2SiL=Wr2SiLNr*SimAreaRelSiL;
     
    % Add output to the matrices with real simulations
     Tr=[Tr,TrSaL,TrSiL];
     Trx=[Trx, TrxSaL, TrxSiL];
     E=[E,ESaL,ESiL];
     Ex=[Ex,ExSaL,ExSiL];
     ETa=[ETa,ETaSaL,ETaSiL];
     ETx=[ETx,ETxSaL,ETxSiL];
     RO=[RO,ROSaL,ROSiL];   
     DP=[DP,DPSaL,DPSiL];   
     CR=[CR,CRSaL,CRSiL]; 
     BundWat=[BundWat,BundWatSaL,BundWatSiL];
     Wr2=[Wr2,Wr2SaL,Wr2SiL];

clear TrSaL TrSiL TrxSaL TrxSiL ESaL ESiL ExSaL ExSiL ETaSaL ETaSiL ETxSaL ETxSiL ROSaL ROSiL DPSaL DPSiL CRSaL CRSiL Wr2SaL Wr2SiL Nr i AreaTotSiL AreaTotSaL SimAreaRelSaL SimAreaRelSiL


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 5. CALCULATE CATCHMENT WEIGHTED AVERAGE OF SOIL WATER BALANCE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%% 5.1 Define weighting factors
     
    % Predefine weighting factors
        Wgt= NaN(nSim,1);% weighting factors for variables that have output for the non-simulated units
        Wgt2=NaN(nRealSim,1);%weigthing factors for variables that have no output for the non-simulated units
    % Calculate weigthing factors
        for i=1:nSim
         Wgt(i,1)=SimArea(i,1)/(AreatotRealSim+AreatotNotSim);
        end
        for i=1:nRealSim 
         Wgt2(i,1)=SimArea(i,1)/(AreatotRealSim);
        end
 
%%%% 5.2 Multiply matrixes to calculate weigthed mean
    TrCatch=Tr*Wgt(:,1);
    TrxCatch=Trx*Wgt(:,1);
    ECatch=E*Wgt(:,1);
    ExCatch=Ex*Wgt(:,1);
    ETaCatch=ETa*Wgt(:,1);
    ETxCatch=ETx*Wgt(:,1);
    ROCatch=RO*Wgt(:,1);
    DPCatch=DP*Wgt(:,1);
    CRCatch=CR*Wgt(:,1);
    BundWatCatch=BundWat*Wgt(:,1);
    Wr2Catch=Wr2*Wgt(:,1);
    CCCatch=CC*Wgt2(:,1);

 clear i Wgt Wgt2

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 6. CREATE OUTPUT MATRICES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%% 6.1 Catchment results
CatchACOutput=[TrCatch,TrxCatch,ECatch,ExCatch,ETaCatch,ETxCatch,ROCatch,DPCatch,CRCatch,BundWatCatch,Wr2Catch,CCCatch,Day(:,1),Month(:,1),Year(:,1)];

%%%% 6.2 Results of individual simulation units
SimACOutput={Tr,Trx,E,Ex,ETa,ETx,RO,DP,CR,BundWat,Wr2,CC,B,Bfin,Y,Day,Month,Year};





