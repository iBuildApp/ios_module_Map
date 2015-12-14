Use our code to save yourself time on cross-platform, cross-device and cross OS version development and testing
# ios_module_Map
Map widget is intended for displaying of Google Map and interaction with it.

General features:

- locations display on the map;
- viewing of each location description in pop-up bubble, which is being displayed while clicking on location icon;
- redirect on website in case if location description has website URL address;
- detection of a current user location;
- creation of the route from current user location to chosen location on the map.

Tags:

- title - widget name. Title is being displayed on navigation panel when widget is launched.
- initialZoom - scale (zoom)of map display. Integer value. If the scale is not defined or value is not valid, scale is being calculated automatically, so all the locations could be displayed on the map at the same time.
- showCurrentUserLocation - defines display of the current user's location. Values - 1 - display and 0 - hide (not display).
- object - root tag containing information about location on the map. More than one location can be set up in XML-configuration.
 - title - location title on the map. Is being displayed in pop-up bubble while clicking on location icon.
 - subtitle - location description. Is being displayed in pop-up bubble while clicking on location icon.
 - latitude - location coordinate: latitude(real value).
 - longitude - location coordinate: longitude (real value).
 - description - url for redirect on web address while clicking on button in location description pop-up. Field is not required.
 - pinurl - url of an image of icon location on the map. Field is not required.
