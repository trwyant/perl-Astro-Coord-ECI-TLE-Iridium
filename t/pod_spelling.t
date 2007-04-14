#!/usr/local/bin/perl

use strict;
use warnings;

my $skip;
BEGIN {
    eval "use Test::Spelling";
    $@ and do {
	eval "use Test";
	plan (tests => 1);
	$skip = 'Test::Spelling not available';;
    };
}

our $VERSION = '0.007_01';

if ($skip) {
    skip ($skip, 1);
} else {
    add_stopwords (<DATA>);

    all_pod_files_spelling_ok ();
}
__DATA__
Above's
accreted
Alasdair
altazimuth
angulardiameter
angularvelocity
appulse
appulsed
appulsing
appulses
argumentofperigee
Astro
au
autoheight
azel
Barycentric
barycentre
body's
boosters
Borkowski
Borkowski's
Brett
Brodowski
bstardrag
CA
ca
Celestrak
Chalpront
cmd
coodinate
Coords
dans
darwin
DateTime
de
deg
degreesDminutesMsecondsS
des
distsq
Dominik
ds
du
dualvar
ECEF
ECI
eci
EDT
edt
edu
elementnumber
ELP
ephemeristype
Escobal
EST
exportable
ff
firstderivative
foo
fr
Francou
Fugina
Gasparovic
gb
geocode
Geocoder
geocoder
GMT
Goran
Green's
harvard
Haversine
haversine
haversines
IDs
illum
illuminator
IMACAT
Imacat
ini
internet
isa
jan
jcent
jday
Jenness
jul
julianday
Kazimierz
Kelso
Kelso's
lib
LLC
ls
Lune
ly
magma
Mariana
McCants
meananomaly
meanmotion
Meeus
mma
mmas
Moon's
MoonPhase
MSWin
NORAD
NORAD's
nouvelles
Obliquity
obliquity
Observatoire
op
oped
orbitaux
Palau
parametres
pbcopy
pbpaste
pc
PE
perigee
perltime
Persei
pg
pm
pp
pre
psiprime
rad
Ramon
readonly
rebless
reblessable
reblessed
reblesses
reblessing
ref
reportable
revolutionsatepoch
Rico
rightascension
Roehric
Saemundsson's
SATCAT
satpass
SATPASSINI
SDP
sdp
secondderivative
semimajor
SGP
sgp
SI
SIGINT
SIMBAD
Simbad
simbad
Sinnott
SKYSAT
skysat
SLALIB
Smart's
solstices
SPACETRACK
Spacetrack
Storable
strasbg
SunTime
Survey's
TAI
TDB
TDT
Terre
thetag
Thorfinn
timekeeping
TIMEZONES
TLE
tle
TT
Touze
Turbo
TWOPI
tz
uk
USGS
UT
UTC
VA
valeurs
webcmd
WGS
Willmann
Wyant
xclip
xxxx
XYZ

