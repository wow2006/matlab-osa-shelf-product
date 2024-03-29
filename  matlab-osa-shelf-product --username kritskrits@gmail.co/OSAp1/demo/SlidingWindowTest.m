%%
global bCheckPoint;
bCheckPoint = true;
if(~bCheckPoint)
    clear all
    bCheckPoint = false;
end
clc;close all;

%%
global bWasInitSwOnce;
global totalMatches;
global bShowSegmentedShelvesWhileSW;
global bDebug;
global SurfShelfOptions;
global SurfProductOptions;
global num_CPUs;


WholeTime = tic;
SURFerrorTresh = 0.18;
[s, w] = dos('set NUMBER_OF_PROCESSORS');
num_CPUs = sscanf(w, '%*21c%d', [1, Inf]);

if ~verLessThan('matlab', '7.13')
    isOpen = matlabpool('size') > 0;
    if(~isOpen)
        matlabpool open
        %matlabpool(num_CPUs);
    end
end


% Add subfunctions to Matlab Search path
cd('..\OpenSURF\');
functionname='OpenSurf.m';
functiondir=which(functionname);
functiondir=functiondir(1:end-length(functionname));
addpath(functiondir);
addpath([functiondir '/WarpFunctions']);

cd('..\demo\');

SurfShelfOptions.upright=true;
SurfShelfOptions.tresh=0.0001;

SurfProductOptions.upright=true;
SurfProductOptions.tresh=0.0001;

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


[shelfObject shelves] = shelfDetectInit( shelves_FileLocation , shelfColor_FileLocation,shelfEmptyColor_FileLocation );
shelves_details = shelfDetect( shelfObject , bCalcEmptyPlace ); %bools = debug,Calculate free space on shelf

figure(999); imshow(shelves);
[productIndex] = ProductInit(product_FileLocation,shelves_details); %plus fix resolution

if(~bCheckPoint)
    [ shelves_details ] = FindSURFonSegmentedShelf( shelves_details );
    backUpVersion_shelves_details = shelves_details;
    [ productIndex ] = FindSURFonProduct( productIndex );
    backUpVersion_productIndex = productIndex;
else
    shelves_details = backUpVersion_shelves_details;
    productIndex = backUpVersion_productIndex;
end

colorPlate=hsv(100);
routeIndex = [];
%figure(777);imshow(routeIndex.shelves); hold on; %inside SWinit now

matchPoints = [];
segmentedShelf = uint8(zeros(size(shelves,1),size(shelves,2)));
offset = 12;

bitmap = shelves_details.SURF.bitmap;
ind = find(bitmap > 0);
shelfSURFdesc = shelves_details.SURF.pts(1,bitmap(ind));
D1 = reshape([shelfSURFdesc.descriptor],64,[]); 
totalMatches = tic;
for ii=1:productIndex.Length
    productSURFdesc = productIndex.SURF.Products(ii).pts;
    
    D2 = reshape([productSURFdesc.descriptor],64,[]); 
    
    % Find the best matches
    err=zeros(1,length(shelfSURFdesc));
    cor1=1:length(shelfSURFdesc); 
    cor2=zeros(1,length(shelfSURFdesc));
    for i=1:length(shelfSURFdesc),
        distance=sum((D2-repmat(D1(:,i),[1 length(productSURFdesc)])).^2,1);
        [err(i),cor2(i)]=min(distance);
    end
    
    % Sort matches on vector distance
    [err, ind]=sort(err);
    
    err = err(err < SURFerrorTresh);
    
    cor1=cor1(ind); 
    cor2=cor2(ind);
    
    cor1=cor1(1:size(err,2)); 
    cor2=cor2(1:size(err,2));
    
    
    % Show the best matches
    for i=1:size(cor1,2),
        x = shelfSURFdesc(cor1(i)).x;
        y = shelfSURFdesc(cor1(i)).y;
        
        sw.product.index = ii;
        sw.product.x = productSURFdesc(cor2(i)).x;
        sw.product.y = productSURFdesc(cor2(i)).y;
        sw.product.leftOffset = max(0,sw.product.x-offset);
        sw.product.rightOffset = min(sw.product.x+offset,size(productIndex.Products(1,sw.product.index).product,2));
        sw.product.upperOffset = max(0,sw.product.y-offset);
        sw.product.bottomOffset = min(sw.product.y+offset,size(productIndex.Products(1,sw.product.index).product,1));
        
        
        sw.shelf.x = shelfSURFdesc(cor1(i)).x;
        sw.shelf.y = shelfSURFdesc(cor1(i)).y;
        sw.shelf.leftOffset = max(0,x-offset);
        sw.shelf.rightOffset = min(x+offset,size(shelves,2));
        sw.shelf.upperOffset = max(0,y-offset);
        sw.shelf.bottomOffset = min(y+offset,size(shelves,1));
        

        sw.shelf.shelfWindow = shelves_details.shelfObject.shelves(sw.shelf.upperOffset:sw.shelf.bottomOffset,sw.shelf.leftOffset:sw.shelf.rightOffset,:);
        sw.shelf.shelfLabWindow = shelves_details.shelfObject.shelfCIELAB(sw.shelf.upperOffset:sw.shelf.bottomOffset,sw.shelf.leftOffset:sw.shelf.rightOffset,:);
        sw.product.productWindow = productIndex.Products(1,sw.product.index).product(sw.product.upperOffset:sw.product.bottomOffset,sw.product.leftOffset:sw.product.rightOffset,:);
        sw.product.productLabWindow = productIndex.Products(1,sw.product.index).ProductCIELAB(sw.product.upperOffset:sw.product.bottomOffset,sw.product.leftOffset:sw.product.rightOffset,:);

        %values 0..1
        corrRGBorig = HistsCorrelation(sw.shelf.shelfWindow,sw.product.productWindow,[1,2,3])
        corrRGB = mean(corrRGBorig);
        corrRGBmin = min(corrRGBorig);
        corrLABorig = HistsCorrelation(sw.shelf.shelfLabWindow,sw.product.productLabWindow,[1,2,3])
        corrLAB = mean(corrLABorig);
        corrLABmin = min(corrLABorig);
        bPaint = true;
        if(bDebug)
            %ShowColorSegmentation(sw,shelves_details,productIndex);
            c=rand(1,3);
            figure(999);hold on;
            tRGB = 0.74;
            tLAB = 0.72;
            bCP = false;
            if(shelfSURFdesc(cor1(i)).x > 870 && shelfSURFdesc(cor1(i)).x < 893 && shelfSURFdesc(cor1(i)).y > 945 && shelfSURFdesc(cor1(i)).y < 1215)
                %ShowColorSegmentation(sw,shelves_details,productIndex);
                %bCP = true;
            end
            if(corrRGB > tRGB && corrLAB > tLAB)
                plot([shelfSURFdesc(cor1(i)).x],[shelfSURFdesc(cor1(i)).y],'o','Color','green');
            else
                %ShowColorSegmentation(sw,shelves_details,productIndex);
                if (corrRGB > tRGB*1.1 && corrLABmin > 0.25)
                    plot([shelfSURFdesc(cor1(i)).x],[shelfSURFdesc(cor1(i)).y],'o','Color','yellow');
                else
                    if (corrLAB > tLAB)
                        plot([shelfSURFdesc(cor1(i)).x],[shelfSURFdesc(cor1(i)).y],'o','Color','blue');
                    else
                        if(corrLAB > 0.4 && mean(corrRGBorig(2:3)) > tRGB*0.9 && abs(corrRGBorig(2)-corrRGBorig(3)) < 0.15 && mean(corrRGBorig(2:3)) - corrRGBorig(1) > 0.4 )
                            %ShowColorSegmentation(sw,shelves_details,productIndex);
                            plot([shelfSURFdesc(cor1(i)).x],[shelfSURFdesc(cor1(i)).y],'o','Color','white');
                        else
                            %ShowColorSegmentation(sw,shelves_details,productIndex);
                            bPaint = false;
                            plot([shelfSURFdesc(cor1(i)).x],[shelfSURFdesc(cor1(i)).y],'o','Color','red');
                        end
                    end
                end
            end
        end
        if (bPaint)
            segmentedShelf(sw.shelf.upperOffset:sw.shelf.bottomOffset,sw.shelf.leftOffset:sw.shelf.rightOffset) = 255;
        else
            segmentedShelf(sw.shelf.upperOffset:sw.shelf.bottomOffset,sw.shelf.leftOffset:sw.shelf.rightOffset) = 0;
        end
    end
end
disp(['total matches : '  num2str(toc(totalMatches)) 'seconds']);

%%
se = strel('disk', offset/2);
I_opened = imdilate(segmentedShelf,se);
shelves_morph = bwareaopen(I_opened, offset*4*9*4);


s  = regionprops(shelves_morph, 'BoundingBox');
figure(99);hold on; 
for i=1:size(s,1)
    rectangle('Position',s(i).BoundingBox,'EdgeColor' ,'green', 'LineWidth',4,'LineStyle','--');
end


% for ii=1:productIndex.Length
%     productTime = tic;
%     productIndex.Products
%     [rect_prod sub_product] = ProductGetByIndex(productIndex,ii,saveFileAs_subImg1);
%     
%     if(bDebug)
%         figure(666); imshow(productIndex.product);
%         figure(666); hold on; rectangle('Position',rect_prod,'EdgeColor' ,'green', 'LineWidth',4,'LineStyle','--');
%     end
%     
%     routeIndex = SWinit(routeIndex,productIndex,shelves_details,rect_prod ,shelves);
%     a = 1;
%     while (~routeIndex.bDoneJob)
%         [ routeIndex,rect_shelf ] = SWsaveJPG( routeIndex,saveFileAs_subImg2 );
%         
%         while(~IsValidPosition( rect_shelf , routeIndex.shelvesSegmented , overLappingPrecentTresh ))
%             [ routeIndex ] = SWadvance( routeIndex );
%             [ routeIndex,rect_shelf ] = SWsaveJPG( routeIndex,saveFileAs_subImg2 );      
%         end
%         
%                
%         if((rect_shelf(3) > rect_prod(3)) && (rect_shelf(4) > rect_prod(4)))
%             if(bShowSegmentedShelvesWhileSW)
%                 if(bDebug)
%                     genColor = colorPlate(randi(100),:);
%                     %figure(777); hold on;rectangle('Position',rect_shelf,'EdgeColor',genColor);
%                     figure(1),subplot(2,3,4);hold on;rectangle('Position',rect_shelf,'EdgeColor',genColor);title({'shelves and empty';'places positions'});
%                 end
%                 %figure(666); hold on;rectangle('Position',rect_shelf,'EdgeColor',colorPlate(randi(100),:));
%             end
%             
%             results = RunASIFTandSaveResults(ii,rect_shelf, saveFileAs_subImg1, saveFileAs_subImg2);
%             matchPoints = [matchPoints; results];
%         end
% 
%         
%         [ routeIndex ] = SWadvance( routeIndex );
%         a= a+1;
%         disp(['total matches : ' num2str(totalMatches)]);
%     end
%     disp(['product #' num2str(ii) ' took ' num2str(toc(productTime)) 'seconds']);
% end
disp(['the whole process took ' num2str(toc(WholeTime)) ' seconds']);