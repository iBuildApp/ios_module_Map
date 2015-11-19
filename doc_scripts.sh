headerdoc2html -j -o mMap/Documentation mMap/mMapDirections.h 
headerdoc2html -j -o mMap/Documentation mMap/mMap.h 


gatherheaderdoc mMap/Documentation


sed -i.bak 's/<html><body>//g' mMap/Documentation/masterTOC.html
sed -i.bak 's|<\/body><\/html>||g' mMap/Documentation/masterTOC.html
sed -i.bak 's|<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">||g' mMap/Documentation/masterTOC.html