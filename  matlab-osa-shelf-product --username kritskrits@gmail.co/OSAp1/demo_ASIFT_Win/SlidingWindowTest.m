%%
clear all;clc;close all;
%%
global bWasInitSwOnce;
global totalMatches;
global bShowSegmentedShelvesWhileSW;

bDebug = true;
bCalcEmptyPlace = true;
bShowSegmentedShelvesWhileSW = true;
overLappingPrecentTresh = 0.15;

product_FileLocation = 'pics\newProduct20.jpg';
shelves_FileLocation = 'pics\shelf40.jpg';
shelfColor_FileLocation = 'pics\shelfCropped.jpg';
shelfEmptyColor_FileLocation = 'pics\empty.jpg';

saveFileAs_subImg1 = 'pics\productExample.jpg';
saveFileAs_subImg2 = 'pics\shelfExample.jpg';

% consts needed
totalMatches = 0;
bWasInitSwOnce = false;
productExampleIndex = 2;
shelfWindowIndex = 1;

[productIndex product] = ProductInit(product_FileLocation);
[shelfObject shelves] = shelfDetectInit( shelves_FileLocation , shelfColor_FileLocation,shelfEmptyColor_FileLocation,bDebug );
%%
shelves_details = shelfDetect( shelfObject , bDebug , bCalcEmptyPlace ); %bools = debug,Calculate free space on shelf
%%
colorPlate=hsv(100);
routeIndex = [];
%figure(777);imshow(routeIndex.shelves); hold on; %inside SWinit now

matchPoints = [];
overallTime = tic;
for ii=1:productIndex.Length
    productTime = tic;
    [rect_prod sub_product] = ProductGetByIndex(productIndex,ii,saveFileAs_subImg1);
    routeIndex = SWinit(routeIndex,productIndex,shelves_details,rect_prod ,shelves);
    a = 1;
    while (~routeIndex.bDoneJob)
        [ routeIndex,rect_shelf ] = SWsaveJPG( routeIndex,saveFileAs_subImg2 );
        
        while(~IsValidPosition( rect_shelf , routeIndex.shelvesSegmented , overLappingPrecentTresh ))
            [ routeIndex ] = SWadvance( routeIndex );
            [ routeIndex,rect_shelf ] = SWsaveJPG( routeIndex,saveFileAs_subImg2 );      
        end
        
               
        if((rect_shelf(3) > rect_prod(3)) && (rect_shelf(4) > rect_prod(4)))
            if(bShowSegmentedShelvesWhileSW)
                figure(777); hold on;rectangle('Position',rect_shelf,'EdgeColor',colorPlate(randi(100),:));
                figure(666); hold on;rectangle('Position',rect_shelf,'EdgeColor',colorPlate(randi(100),:));
            end
            
            results = RunASIFTandSaveResults(ii,rect_shelf, saveFileAs_subImg1, saveFileAs_subImg2);
            matchPoints = [matchPoints; results];
        end

        
        [ routeIndex ] = SWadvance( routeIndex );
        a= a+1;
        disp(['total matches : ' num2str(totalMatches)]);
    end
    disp(['product #' num2str(ii) ' took ' num2str(toc(productTime)) 'seconds']);
end
disp(['the whole process took ' num2str(toc(overallTime)) 'seconds']);