%%
clear all;clc;close all;
%%
file_img1 = 'coffee_namess.jpg';
file_img2 = 'shelf.jpg';

product = imread(file_img1);
shelves = imread(file_img2);

saveFileAs_subImg1 = 'productExample.jpg';
saveFileAs_subImg2 = 'shelfExample.jpg';

productExampleIndex = 2;
shelfWindowIndex = 1;

productIndex = ProductInit(product);
[rect_prod sub_product] = ProductGetByIndex(productIndex,productExampleIndex,[]);
routeIndex  = SWinit(rect_prod ,shelves);

colorPlate=hsv(100);
figure();imshow(shelves); hold on;
while (~routeIndex.bDoneJob)
    [ routeIndex,rect_shelf ] = SWsaveJPG( routeIndex,[] );
    rectangle('Position',rect_shelf,'EdgeColor',colorPlate(randi(100),:));
    [ routeIndex ] = SWadvance( routeIndex );
end