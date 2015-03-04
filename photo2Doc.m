%% image information
img = imread('TestImages/TestEx1-1.jpg');
width = size(img, 2);
height = size(img, 1);
channel = size(img, 3);
dimension = length(img);

figure;
imshow(img);
pause;

%% thresholding
imgDist = uint8(sqrt((sum(double(255 - img) .^ 2, 3))));
windowSize = round(dimension * 0.5);
imgMean = imfilter(imgDist, fspecial('average', windowSize), 'replicate');
imgDiff = single(imgDist) - single(imgMean);
thresh = graythresh(imgDiff); 
imgBW = imcomplement(im2bw(imgDiff, thresh));
imgBWFilled = imfill(imgBW, 8, 'holes');
structureSize = round(dimension * 0.001);
se = strel('disk', structureSize);
erodeTimes = 0;
imgBWRect = imgBWFilled;
CC = bwconncomp(imgBWRect);
while CC.NumObjects > 1
    imgBWRect = imerode(imgBWRect, se);
    erodeTimes = erodeTimes + 1;
    CC = bwconncomp(imgBWRect);
end
se = strel('square', erodeTimes * structureSize);
for i = 1 : erodeTimes
    imgBWRect = imdilate(imgBWRect, se);
end
figure;
imshow(imgBWRect);
pause;

%% corner detection
cornerFilterRadius = round(dimension / 100) * 2 + 1;
cornerFilter = fspecial('gaussian', [cornerFilterRadius 1], cornerFilterRadius / 3);
corners = corner(imgBWRect, 4, 'FilterCoefficients', cornerFilter);
corners(:, [1, 2]) = corners(:, [2, 1]);

dists = corners(:, 1) .^ 2 + corners(:, 2) .^ 2;
[minDist, minIdx] = min(dists);
upperLeft = corners(minIdx, :);
corners(minIdx, :) = [];
dists = (corners(:, 1) - upperLeft(1)) .^ 2 + (corners(:, 2) - upperLeft(2)) .^ 2;
[maxDist, maxIdx] = max(dists);
lowerRight = corners(maxIdx, :);
corners(maxIdx, :) = [];
if dot(corners(1, :) - upperLeft, lowerRight - upperLeft) > 0
    upperRight = corners(1, :);
    lowerLeft = corners(2, :);
else
    upperRight = corners(2, :);
    lowerLeft = corners(1, :);
end

figure;
imshow(img);
hold on;
plot(upperLeft(2), upperLeft(1), 'c*');
plot(upperRight(2), upperRight(1), 'm*');
plot(lowerRight(2), lowerRight(1), 'y*');
plot(lowerLeft(2), lowerLeft(1), 'k*');
pause;

%% homography transformation
newWidth = round((pdist2(upperLeft, upperRight) + pdist2(lowerLeft, lowerRight)) / 2);
newHeight = round((pdist2(upperLeft, lowerLeft) + pdist2(upperRight, lowerRight)) / 2);
newDimension = max([newWidth newHeight]);
cp1 = [upperLeft; upperRight; lowerRight; lowerLeft];
cp2 = [1, 1; 1, newWidth; newHeight, newWidth; newHeight, 1];

A = zeros(8, 8);
b = zeros(8, 1);
for i = 1:size(cp1,1)
    A(2*i-1,1) = cp2(i,1);
    A(2*i-1,2) = cp2(i,2);
    A(2*i-1,3) = 1;
    A(2*i-1,7) = -cp1(i,1)*cp2(i,1);
    A(2*i-1,8) = -cp1(i,1)*cp2(i,2);
    b(2*i-1) = cp1(i,1);
    A(2*i,4) = cp2(i,1);
    A(2*i,5) = cp2(i,2);
    A(2*i,6) = 1;
    A(2*i,7) = -cp1(i,2)*cp2(i,1);
    A(2*i,8) = -cp1(i,2)*cp2(i,2);
    b(2*i) = cp1(i,2);
end
h = A \ b;
H = [h(1) h(2) h(3); h(4) h(5) h(6); h(7) h(8) 1];

newImgRaw = zeros([newHeight newWidth channel], 'uint8');
for y = 1 : newHeight
    for x = 1 : newWidth
        p1 = [y; x; 1];
        p2 = H * p1;
        p2 = p2 ./ p2(3);
        if p2(1) >= 1 && p2(1) <= height && p2(2) >= 1 && p2(2) <= width
            newImgRaw(y, x, :) = img(round(p2(1)), round(p2(2)), :);
        end
    end
end

figure;
imshow(newImgRaw);
pause;

%% image enhancement
filterRadius = round(newDimension / 20) * 2 + 1;
filter = fspecial('gaussian', [filterRadius filterRadius], filterRadius / 3);
newImgLFiltered = imfilter(newImgRaw, filter, 'replicate');
newImg = uint8(double(newImgRaw) ./ double(newImgLFiltered) * 255);

figure;
imshow(newImg);
