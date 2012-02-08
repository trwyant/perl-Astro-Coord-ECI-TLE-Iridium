package main;

use strict;
use warnings;

use Astro::Coord::ECI;
use Astro::Coord::ECI::Utils qw{ :time deg2rad PERL2000 rad2deg };
use POSIX qw{strftime floor};
use Test::More 0.88;

use constant EQUATORIALRADIUS => 6378.14;	# Meeus page 82.
use constant TIMFMT => '%d-%b-%Y %H:%M:%S';

Astro::Coord::ECI->set (debug => 0);

sub tolerance (@);
sub tolerance_band (@);

# universal time
# Tests: universal()

# We just make sure we get the same thing back.

{
    my $want = timegm ( 0, 0, 0, 1, 0, 100 );
    my $got = Astro::Coord::ECI->universal( $want )->universal();

    cmp_ok $got, '==', $want,
	'Univeral time round trip: Jan 1 2000';

    $want = timegm ( 0, 0, 0, 1, 0, 105 );
    $got = Astro::Coord::ECI->universal( $want )->universal();

    cmp_ok $got, '==', $want,
	'Univeral time round trip: Jan 1 2005';
}


# universal time -> dynamical time
# Tests: dynamical()

{
    my $univ = timegm( 0, 0, 0, 1, 0, 100 );
    my $dyn = floor(
	Astro::Coord::ECI->universal( $univ )->dynamical + .5 );

    cmp_ok $dyn, '==', $univ + 65,
	'Universal to dynamical time: Jan 1 2000';

    $univ = timegm( 0, 0, 0, 1, 0, 105 );
    $dyn = floor(
	Astro::Coord::ECI->universal( $univ )->dynamical + .5 );

    cmp_ok $dyn, '==', $univ + 72,
	'Universal to dynamical time: Jan 1 2005';
}


# dynamical time -> universal time
# tests: dynamical()

{
    my $dyn = timegm( 0, 0, 0, 1, 0, 100 );
    my $univ = floor(
	Astro::Coord::ECI->dynamical( $dyn
	)->universal() + .5 );

    cmp_ok $univ, '==', $dyn - 65,
	'Dynamical to universal time: Jan 1 2000 dynamical';

    $dyn = timegm( 0, 0, 0, 1, 0, 105 );
    $univ = floor(
	Astro::Coord::ECI->dynamical( $dyn
	)->universal() + .5 );

    cmp_ok $univ, '==', $dyn - 72,
	'Dynamical to universal time: Jan 1 2005 dynamical';
}


# ecef
# Tests: ecef()

# All we do here is be sure we get back what we put in.

{
    my ( $X, $Y, $Z ) = Astro::Coord::ECI->ecef( 3000, 4000, 5000 )->ecef();

    cmp_ok $X, '==', 3000, 'ECEF round-trip: X';

    cmp_ok $Y, '==', 4000, 'ECEF round-trip: Y';

    cmp_ok $Z, '==', 5000, 'ECEF round-trip: Z';
}


# geodetic -> geocentric
# Tests: geodetic()

# Meeus, page 82, example 11a

# Both TopoZone and Google say the observatory is latitude 34 deg 13'33"
# N (=   degrees), longitude 118 deg 03'25" W (= -118.056944444444
# degrees).  The test uses Meeus' latitude of 33 deg 21'22" N (since
# that's what Meeus himself uses) but the TopoZone/Google value for
# longitude, since longitude does not affect the calculation, but my
# Procrustean validation expects it.

# We also test the antpodal (sort of) point, since finding a bug in my
# implementation of Borkowski's algorithm when running on a point in the
# southern hemisphere. No, this particular test doesn't use that
# algorithm, but once bitten, twice shy.

{
    my ( $phiprime, undef, $rho ) =
	Astro::Coord::ECI->new( ellipsoid => 'IAU76' )->
	geodetic( .58217396455, -2.060487233536, 1.706 )->geocentric();
    my $rhosinphiprime = $rho / EQUATORIALRADIUS * sin ($phiprime);
    my $rhocosphiprime = $rho / EQUATORIALRADIUS * cos ($phiprime);

    cmp_ok sprintf( '%.6f', $rhosinphiprime ), '==', .546861,
	'geodetic to geocentric: rho * sin( phiprime )';

    cmp_ok sprintf( '%.6f', $rhocosphiprime ), '==', .836339,
	'geodetic to geocentric: rho * cos( phiprime )';

    ( $phiprime, undef, $rho ) =
	Astro::Coord::ECI->new( ellipsoid => 'IAU76' )->
	geodetic( -.58217396455, 2.060487233536, 1.706 )->geocentric();
    $rhosinphiprime = $rho / EQUATORIALRADIUS * sin ($phiprime);
    $rhocosphiprime = $rho / EQUATORIALRADIUS * cos ($phiprime);

    cmp_ok sprintf( '%.6f', $rhosinphiprime ), '==', -.546861,
	'geodetic to geocentric: rho * sin( phiprime )';

    cmp_ok sprintf( '%.6f', $rhocosphiprime ), '==', .836339,
	'geodetic to geocentric: rho * cos( phiprime )';
}


# geocentric -> geodetic
# Tests: geodetic()

# Borkowski
# For this, we just invert Meeus' example.

# We also test the antpodal point, since finding a bug in my
# implementation of Borkowski's algorithm when running on a point in the
# southern hemisphere.

{
    my ( $lat, $long, $elev ) =
	Astro::Coord::ECI->new( ellipsoid => 'IAU76' )->
	geocentric(
	    0.579094339305825, -2.060487233536, 6373.41803380646,
	)->geodetic();

    tolerance_band $lat, .58217396455, 1e-6,
	'Geocentric to geodetic: latitude';

    tolerance_band $long, -2.060487233536, 1e-6,
	'Geocentric to geodetic: longitude';

    tolerance_band $elev, 1.706, 1e-3,
	'Geocentric to geodetic: height above sea level';

#	[IAU76 => -0.579094339305825, 1.08110542005979, 6373.41803380646,
#		[-.58217396455, 1e-6], [1.08110542005979, 1e-6], [1.706, 1e-3]],
#	) {

    ( $lat, $long, $elev ) =
	Astro::Coord::ECI->new( ellipsoid => 'IAU76' )->
	geocentric(
	    -0.579094339305825, 1.08110542005979, 6373.41803380646,
	)->geodetic();

    tolerance_band $lat, -.58217396455, 1e-6,
	'Geocentric to geodetic: latitude';

    tolerance_band $long, 1.08110542005979, 1e-6,
	'Geocentric to geodetic: longitude';

    tolerance_band $elev, 1.706, 1e-3,
	'Geocentric to geodetic: height above sea level';
}

# geodetic -> Earth-Centered, Earth-Fixed
# Tests: geocentric() (and geodetic())

# Continuing the above example, but ecef coordinates. Book answer from
# http://www.ngs.noaa.gov/cgi-bin/xyz_getxyz.prl is
#    x                y             z       Elipsoid
# -2508975.4549 -4707403.8939  3487953.2711 GRS80

note <<'EOD';

In the following twelve tests the tolerance is degraded because the book
solution is calculated using a different, and apparently simpler model
attributed to Escobal, "Methods of Orbit Determination", 1965, Wiley &
Sons, Inc., pp. 27-29.

EOD

{
    my ( $x, $y, $z ) =
	Astro::Coord::ECI->new( ellipsoid => 'GRS80' )->
	geodetic( .58217396455, -2.060487233536, 1.706 )->ecef();

    tolerance_band $x, -2508.9754549, 1e-5,
	'Geodetic to ECEF: X';

    tolerance_band $y, -4707.4038939, 1e-5,
	'Geodetic to ECEF: Y';

    tolerance_band $z, 3487.9532711, 1e-5,
	'Geodetic to ECEF: Z';

    ( $x, $y, $z ) =
	Astro::Coord::ECI->new( ellipsoid => 'GRS80' )->
	geodetic( -.58217396455, 1.08110542005979, 1.706 )->ecef();

    tolerance_band $x, 2508.9754549, 1e-5,
	'Geodetic to ECEF: X';

    tolerance_band $y, 4707.4038939, 1e-5,
	'Geodetic to ECEF: Y';

    tolerance_band $z, -3487.9532711, 1e-5,
	'Geodetic to ECEF: Z';
}


# Earth-Centered, Earth-Fixed -> geodetic
# Tests: geocentric() (and geodetic())

# Continuing the above example, but ecef coordinates. We use the book
# solution of the opposite test as our input, and vice versa.

{
    my ( $lat, $long, $elev ) =
	Astro::Coord::ECI->new( ellipsoid => 'GRS80' )->
	ecef( -2508.9754549, -4707.4038939, 3487.9532711 )->geodetic();

    tolerance_band $lat, .58217396455, 1e-5,
	'ECEF to Geodetic: latitude';

    tolerance_band $long, -2.060487233536, 1e-5,
	'ECEF to Geodetic: longitude';

    tolerance_band $elev, 1.706, 1e-5,
	'ECEF to Geodetic: height above sea level';

    ( $lat, $long, $elev ) =
	Astro::Coord::ECI->new( ellipsoid => 'GRS80' )->
	ecef( 2508.9754549, 4707.4038939, -3487.9532711 )->geodetic();

    tolerance_band $lat, -.58217396455, 1e-5,
	'ECEF to Geodetic: latitude';

    tolerance_band $long, 1.08110542005979, 1e-5,
	'ECEF to Geodetic: longitude';

    tolerance_band $elev, 1.706, 1e-5,
	'ECEF to Geodetic: height above sea level';
}


# geodetic -> eci
# Tests: eci() (and geodetic() and geocentric())

# Standard is from http://celestrak.com/columns/v02n03/ (Kelso)

{
    my $time = timegm( 0, 0, 9, 1, 9, 95 );

    my ( $x, $y, $z ) =
	Astro::Coord::ECI->new( ellipsoid => 'WGS72' )->
	geodetic( deg2rad( 40 ), deg2rad( -75 ), 0 )->eci( $time );

    tolerance_band $x, 1703.295, 1e-6, 'Geodetic to ECI: X';

    tolerance_band $y, 4586.650, 1e-6, 'Geodetic to ECI: Y';

    tolerance_band $z, 4077.984, 1e-6, 'Geodetic to ECI: Z';

    $time = timegm( 0, 0, 9, 1, 9, 95 );

    ( $x, $y, $z ) =
	Astro::Coord::ECI->new( ellipsoid => 'WGS72' )->
	geodetic( deg2rad( -40 ), deg2rad( 105 ), 0 )->eci( $time );

    tolerance_band $x, -1703.295, 1e-6, 'Geodetic to ECI: X';

    tolerance_band $y, -4586.650, 1e-6, 'Geodetic to ECI: Y';

    tolerance_band $z, -4077.984, 1e-6, 'Geodetic to ECI: Z';
}


# eci -> geodetic
# Tests: eci() (and geodetic() and geocentric())

# This is the reverse of the previous test.

{
    my $time = timegm( 0, 0, 9, 1, 9, 95 );

    my ( $lat, $long, $elev ) =
	Astro::Coord::ECI->new( ellipsoid => 'WGS72' )->
	eci( 1703.295, 4586.650, 4077.984, $time )->geodetic();

    tolerance_band $lat, deg2rad( 40 ), 1e-6,
	'ECI to geodetic: latitude';

    tolerance_band $long, deg2rad( -75 ), 1e-6,
	'ECI to geodetic: longitude';

    $elev += EQUATORIALRADIUS;
    tolerance_band $elev, EQUATORIALRADIUS, 1e-6,
	'ECI to geodetic: distance from center';

    $time = timegm (0, 0, 9, 1, 9, 95);

    ( $lat, $long, $elev ) =
	Astro::Coord::ECI->new( ellipsoid => 'WGS72' )->
	eci( -1703.295, -4586.650, -4077.984, $time )->geodetic();

    tolerance_band $lat, deg2rad( -40 ), 1e-6,
	'ECI to geodetic: latitude';

    tolerance_band $long, deg2rad( 105 ), 1e-6,
	'ECI to geodetic: longitude';

    $elev += EQUATORIALRADIUS;
    tolerance_band $elev, EQUATORIALRADIUS, 1e-6,
	'ECI to geodetic: distance from center';
}


# azel
# Tests: azel() (and geodetic(), geocentric(), and eci())

# Book solution from
# http://www.satcom.co.uk/article.asp?article=1

note <<'EOD';

In the following three tests the tolerance is degraded because the
book solution is calculated by http://www.satcom.co.uk/article.asp?article=1
which apparently assumes an exactly synchronous orbit. Their exact
altitude assumption is undocumented, as is their algorithm. So the
tests are really more of a sanity check.

EOD

{
    my $time = timegm (0, 0, 5, 27, 7, 105);
    my $sta = Astro::Coord::ECI->new( ellipsoid => 'GRS80' )->
	geodetic( deg2rad( 38 ), deg2rad( -80 ), 1 );
    my $sat = Astro::Coord::ECI->new( ellipsoid => 'GRS80' )->
	universal( $time )->
	geodetic( deg2rad( 0 ), deg2rad( -75 ), 35800 );

    my ( $azm, $elev, $rng ) = $sta->azel( $sat );

    tolerance_band $azm, deg2rad( 171.906 ), 1e-3,
	'Azimuth for observer';

    tolerance_band $elev, deg2rad( 45.682 ), 1e-3,
	'Elevation for observer';

    tolerance_band $rng, 37355.457, 1e-3,
	'Range for observer';

    # enu
    # Tests: enu()

    # From the azel() test above, converted as described at
    # http://geostarslib.sourceforge.net/main.html#conv

    my ( $East, $North, $Up ) = $sta->enu( $sat );

    tolerance $East, 3675, 10,
	'East for observer';

    tolerance $North, -25840, 10,
	'North for observer';

    tolerance $Up, 26746, 10,
	'Up for observer';
}

# atmospheric refraction.
# Tests: correct_for_refraction()

# Based on Meeus' Example 16.a.

{
    my $got = Astro::Coord::ECI->
	correct_for_refraction( deg2rad( .5541 ) );

    tolerance_band $got, deg2rad( 57.864 / 60 ), 1e-4,
	'Correction for atmospheric refraction';
}


# Angle between two points as seen from a third.
# Tests: angle()

{
    my $A = Astro::Coord::ECI->ecef( 0, 0, 0 );
    my $B = Astro::Coord::ECI->ecef( 1, 0, 0 );
    my $C = Astro::Coord::ECI->ecef( 0, 1, 0 );

    my $got = $A->angle ($B, $C);

    tolerance $got, deg2rad( 90 ), 1e-6,
	'Angle between two points as seen from a third';
}


# Precession of equinoxes.
# Tests: precession()

# Based on Meeus' example 21.b.

use constant LIGHTYEAR2KILOMETER => 9.4607e12;

{
    my $alpha0 = 41.054063;
    my $delta0 = 49.227750;
    my $rho = 36.64;
    my $t0 = PERL2000;
    my $alphae = deg2rad( 41.547214 );
    my $deltae = deg2rad( 49.348483 );
    my $time = timegm( 0, 0, 0, 13, 10, 128 ) + .19 * 86400;

    my $eci = Astro::Coord::ECI->dynamical( $t0 )->equatorial(
	deg2rad( $alpha0 ), deg2rad( $delta0 ),
	$rho *  LIGHTYEAR2KILOMETER )->set( equinox_dynamical => $t0 );
    my $utim = Astro::Coord::ECI->dynamical( $time )->universal();
    my ( $alpha, $delta ) = $eci->precess( $utim )->equatorial();
    my $tolerance = 1e-6;

    tolerance $alpha, $alphae, $tolerance,
	'Precession of equinoxes: right ascension';

    tolerance $delta, $deltae, $tolerance,
	'Precession of equinoxes: declination';
}


# Right ascension/declination to ecliptic lat/lon
# Tests: ecliptic() (and obliquity())

# Based on Meeus' example 13.a, page 95.

# Meeus' example involves the star Pollux. We use an arbitrary (and much
# too small) rho, because it doesn't come into the conversion anyway.
# The time matters because it figures in to the obliquity of the
# ecliptic. Unfortunately Meeus didn't give us the time in his example,
# only the obliquity. The time used in the example was chosen because it
# gave the desired obliquity value of 23.4392911 degrees.

{
    my $time = timegm( 36, 27, 2, 30, 6, 109 );

    my ( $lat, $long ) = Astro::Coord::ECI->equatorial(
	deg2rad( 116.328942 ), deg2rad( 28.026183 ), 1e12, $time )->ecliptic();

    tolerance_band $lat, deg2rad( 6.684170 ), 1e-6,
	'Equatorial to Ecliptic: latitude';


    tolerance_band $long, deg2rad( 113.215630 ), 1e-6,
	'Equatorial to Ecliptic: longitude';
}


# Ecliptic lat/lon to right ascension/declination
# Tests: ecliptic() (and obliquity())

# Based on inverting the above test.

{
    my $time = timegm( 36, 27, 2, 30, 6, 109 );

    my ( $ra, $dec ) = Astro::Coord::ECI->ecliptic(
	deg2rad( 6.684170 ), deg2rad( 113.215630 ), 1e12, $time )->equatorial();

    tolerance_band $ra, deg2rad( 116.328942 ), 1e-6,
	'Ecliptic to Equatorial: Right ascension';

    tolerance_band $dec, deg2rad( 28.026183 ), 1e-6,
	'Ecliptic to Equatorial: Declination';
}

use constant ASTRONOMICAL_UNIT => 149_597_870; # Meeus, Appendix 1, pg 407

# Ecliptic lat/long to ECI
# Tests: equatorial() (and ecliptic())

# This test is based on Meeus' example 26.a.

{
    my $time = timegm( 0, 0, 0, 13, 9, 92 );
    my $lat = .62 / 3600;
    my $lon = 199.907347;
    my $rho = .99760775 * ASTRONOMICAL_UNIT;
    my $expx = -0.9379952 * ASTRONOMICAL_UNIT;
    my $expy = -0.3116544 * ASTRONOMICAL_UNIT;
    my $expz = -0.1351215 * ASTRONOMICAL_UNIT;

    my ( $x, $y, $z ) = Astro::Coord::ECI->dynamical( $time )->
	ecliptic( deg2rad( $lat ), deg2rad( $lon ), $rho
	)->eci();
    my $tolerance = 1e-5;

    tolerance_band $x, $expx, $tolerance, 'Ecliptic to ECI: X';

    tolerance_band $y, $expy, $tolerance, 'Ecliptic to ECI: Y';

    tolerance_band $z, $expz, $tolerance, 'Ecliptic to ECI: Z';
}

# universal time to local mean time
# Tests: local_mean_time()

# This test is based on http://www.statoids.com/tconcept.html

{
    my $time = timegm( 0, 0, 0, 1, 0, 101 );
    my $lat = 29/60 + 40;
    my $lon = -( 8/60 + 86 );
    my $offset = -( ( 5 * 60 + 44 ) * 60 + 32 );

    my $got = floor( Astro::Coord::ECI->geodetic(
	    deg2rad( $lat ), deg2rad( $lon ), 0 )->universal(
	    $time )->local_mean_time() );
    my $want = $time + $offset;

    cmp_ok $got, '==', $want, 'Universal time to Local mean time';
}


# local mean time to universal time
# Tests: local_mean_time()

# This test is the inverse of the previous one.

{
    my $time = timegm( 28, 15, 18, 31, 11, 100 );
    my $lat = 29/60 + 40;
    my $lon = -( 8/60 + 86 );
    my $offset = -( ( 5 * 60 + 44 ) * 60 + 32 );

    my $got = floor( Astro::Coord::ECI->geodetic(
	    deg2rad( $lat ), deg2rad( $lon ), 0 )->local_mean_time(
	    $time )->universal() + .5 );
    my $want = $time - $offset;

    cmp_ok $got, '==', $want, 'Local mean time to universal time';
}


# Equatorial coordinates relative to observer.

# I don't have a book solution for this, but if I turn off atmospheric
# refraction, you should get the same result as if you simply subtract
# the ECI coordinates of the observer from the ECI coordinates of the
# body.


{	# Begin local symbol block;
    my $time = time ();
    my $station = Astro::Coord::ECI->geodetic(
	deg2rad (  38.898741 ),
	deg2rad ( -77.037684 ),
	0.01668
    );
    $station->set( refraction => 0 );
    my $body = Astro::Coord::ECI->eci(
	2328.97048951, -5995.22076416, 1719.97067261,
	2.91207230, -0.98341546, -7.09081703, $time);
    my @staeci = $station->eci( $time );
    my @bdyeci = $body->eci();
    my @want = Astro::Coord::ECI->eci(
	    ( map {$bdyeci[$_] - $staeci[$_]} 0 .. 5 ), $time )->
	    equatorial();
    my @got = $station->equatorial ($body);

    tolerance $got[0], $want[0], 0.000001,
	'Right ascension relative to observer';

    tolerance $got[1], $want[1], 0.000001,
	'Declination relative to observer';

    tolerance $got[2], $want[2], 0.000001,
	'Right ascension relative to observer';

}	# End local symbol block.

# represents().

is( Astro::Coord::ECI->represents(), 'Astro::Coord::ECI',
    'Astro::Coord::ECI->represents() returns itself' );

ok( Astro::Coord::ECI->represents( 'Astro::Coord::ECI' ),
    q{Astro::Coord::ECI->represents('Astro::Coord::ECI') is true} );

ok( ! Astro::Coord::ECI->represents( 'Astro::Coord::ECI::TLE' ),
    q{Astro::Coord::ECI->represents('Astro::Coord::ECI::TLE') is false} );

{
    # Maidenhead Locator System. Reference implementation is at
    # http://home.arcor.de/waldemar.kebsch/The_Makrothen_Contest/fmaidenhead.html
    my $got;
    my ( $lat, $lon ) = ( 38.898748, -77.037684 );

    my $sta = Astro::Coord::ECI->new()->geodetic(
	deg2rad( $lat ),
	deg2rad( $lon ),
	0,
    );


    ( $got ) = $sta->maidenhead( 3 );
    is $got, 'FM18lv', "Maidenhead precision 3 for $lat, $lon is 'FM18lv'";

    ( $got ) = $sta->maidenhead( 2 );
    is $got, 'FM18', "Maidenhead precision 2 for $lat, $lon is 'FM18'";

    ( $got ) = $sta->maidenhead( 1 );
    is $got, 'FM', "Maidenhead precision 1 for $lat, $lon is 'FM'";

}

done_testing;

sub tolerance (@) {
    my ( $got, $want, $tolerance, $title ) = @_;
    $title =~ s{ (?<! [.] ) \z }{.}smx;
    my $rslt = abs( $got - $want ) < $tolerance;
    $rslt or $title .= <<"EOD";

         Got: $got
    Expected: $want
EOD
    chomp $title;
    @_ = ( $rslt, $title );
    goto &ok;
}

sub tolerance_band (@) {
    my ( $got, $want, $tolerance, $title ) = @_;
    @_ = ( $got, $want, $tolerance * abs $want, $title );
    goto &tolerance;
}

# Former tests 69-72 were moved to be the first four tests in
# t/eci_maidenhead.t.

# need to test:
#    dip
#    get (class, object)
#    reference_ellipsoid
#    set (class, object with and without resetting the object)

1;

# ex: set textwidth=72 :
