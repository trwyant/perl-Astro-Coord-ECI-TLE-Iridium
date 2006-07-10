=head1 NAME

Astro::Coord::ECI::TLE::Set - Represent a set of data for the same ID.

=head1 SYNOPSIS

 my @sats = Astro::Coord::ECI::TLE::Set->aggregate (
     Astro::Coord::ECI::TLE->parse ($tle_data));
 my $now = time ();
 foreach my $tle (@sats) {
    print join ("\t",
       $tle->get ('id'),
       $tle->universal ($now)->geodetic ()),
       "\n";
 }

=head1 DESCRIPTION

=for comment help syntax-highlighting editor "

This module is intended to represent a set of orbital elements,
representing the same NORAD ID at different points in time. It
can contain any number of objects of class Astro::Coord::ECI::TLE
(or any subclass thereof) provided all contents are of the same
class and represent the same NORAD ID. If you set the time,
the member whose epoch best represents that time is selected, and
subsequent method calls are delegated to that member. Setting a
different time selects a different member. Possibly.

In addition to the methods documented here, an
Astro::Coord::ECI::TLE::Set supports all methods provided by the
currently-selected member object, through Perl's AUTOLOAD mechanism.
In this way, the object is almost a plug-compatible replacement for
an Astro::Coord::ECI::TLE object, but it uses the orbital elements
appropriate to the time given. The weasel word 'almost' is expanded
on in the L</Incompatibilities with Astro::Coord::ECI::TLE> section,
below.

The 'best representative' member for a given time is chosen by
considering all members in the set, ordered by ascending epoch. If all
epochs are after the given time, the earliest epoch is chosen. If some
epochs are on or before the given time, the latest epoch that is not
after the given time is chosen.

The 'best representative' algorithm tries select the element set that
would actually be current at the given time. If no element set is
current (i.e. all are in the future at the given time) we take the
earliest, to minimize peeking into the future.

There may be cases where the member class does not want to use the
normal delegation mechanism. In this case, it needs to define a
_nodelegate_xxxx method, where xxxx is the name of the method that
is not to be delegated to. The _nodelegate method is called with the
same calling sequence as the original method, but the first argument
is a reference to the Astro::Coord::ECI::TLE::Set object, not the
member object. Use of this mechanism constitutes a pledge that the
_nodelegate method does not make use of any private interfaces to the
member objects.

=head2 Incompatibilities with Astro::Coord::ECI::TLE

=head3 Inheritance

Astro::Coord::ECI::TLE::Set is not a member of the Astro::Coord::ECI
inheritance hierarchy, so $set->isa ('Astro::Coord::ECI') is false.

=head3 Calling semantics for delegated behaviors

In general, when Astro::Coord::ECI::TLE::Set delegates functionality
to a member object, that object's method receives a reference to the
member object as its first argument. That is, if $set is the
Astro::Coord::ECI::TLE::Set object and $tle is the relevant member
object, $set->method (...) becomes $tle->method (...) from the point
of view of the called method.

If the member class wishes to see the Astro::Coord::ECI::TLE::Set
object as the first argument of method xxxx, it defines method
_nodelegate_xxxx, which is called as though by $set->_nodelegate_xxx
(...). The _nodelegate_xxx method must use only the public interface
to the $tle object (whatever its class). A cheap way to get this
method is

 *_nodelegate_xxxx = \&xxxx;

but nothing says the _nodelegate_xxxx method B<must> be defined this
way.

=head3 Calling semantics for static behaviors

Some Astro::Coord::ECI methods (e.g. universal()) will instantiate an
object for you if you call them statically. This will not work with
Astro::Coord:ECI::TLE::Set; that is,
Astro::Coord::ECI::TLE::Set->universal () is an error.

=head3 Return semantics for delegated behaviors

In general, methods which return the object they were called on (e.g.
$object->ecef ($X, $Y, $Z ...) return the Astro::Coord::ECI object,
not the Astro::Coord::ECI::TLE::Set object. This does not necessarily
apply to methods implemented on Astro::Coord::ECI::TLE::Set; see the
documentation to those methods for details.

=head2 Methods

The following methods should be considered public:

=for comment help syntax-highlighting editor "

=over

=cut

use strict;
use warnings;

package Astro::Coord::ECI::TLE::Set;

use Carp;
use UNIVERSAL qw{isa};

our $VERSION = '0.000_02';

use constant ERR_NOCURRENT => <<eod;
Error - Can not call %s because there is no current member. Be
        sure you called add() after instantiating or calling clear().
eod


=item $set = Astro::Coord::ECI::TLE::Set->new ()

This method instantiates a new set. Any arguments are passed to the
add() method.

=cut

sub new {
my $class = shift;
$class = ref $class if ref $class;
my $self = {
    current => undef,	# Current member
    members => [],	# [epoch, TLE].
    universal => undef,	# Current time setting.
    };
bless $self, $class;
$self->add (@_) if @_;
$self;
}


=item $set->add ($member ...);

This method adds members to the set. The initial member may be any
initialized member of the Astro::Coord::ECI::TLE class, or any
subclass thereof. Subsequent members must be the same class as
the initial member, and represent the same NORAD ID. If not, an
exception is thrown. If a prospective member has the same epoch
as a current member, the prospective member is silently ignored.

The first member added becomes the current member for the purpose
of delegating method calls. Adding subsequent members does not
change the current member, though it may be appropriate to call
select() after adding.

=cut

sub add {
my $self = shift;
my ($id, %ep, $class);
foreach (@{$self->{members}}) {
    my ($epoch, $tle) = @$_;
    $id ||= $tle->get ('id');
    $class ||= ref $tle;
    $ep{$tle->get ('epoch')} = $tle;
    }
foreach my $tle (@_) {
    my $aid = $tle->get ('id');
    if (defined $id) {
	croak <<eod unless ref $tle && isa ($tle, $class);
Error - Additional member of @{[__PACKAGE__]} must be a
        subclass of $class
eod
        croak <<eod if $aid != $id;
Error - NORAD ID mismatch. Trying to add ID $aid to set defined
        as ID $id.
eod
	}
      else {
	croak <<eod unless ref $tle && isa ($tle, 'Astro::Coord::ECI::TLE');
Error - First member of @{[__PACKAGE__]} must be a subclass
        of Astro::Coord::ECI::TLE.
eod
	$class = ref $tle;
	$id = $aid;
	$self->{current} = $tle;
	}
    my $aep = $tle->get ('epoch');
    next if $ep{$aep};
    $ep{$aep} = $tle;
    }
@{$self->{members}} = sort {$a->[0] <=> $b->[0]}
    map {[$_, $ep{$_}]} keys %ep;
}


=item @sets = Astro::Coord::ECI::TLE::Set->aggregate ($tle ...);

This method aggregates the given Astro::Coord::ECI::TLE objects into
sets by NORAD ID. If there is only one object with a given NORAD ID, it
is simply returned intact, B<not> made into a set with one member.

=cut

sub aggregate {
my $class = shift;
$class = ref $class if ref $class;
my %data;
foreach my $tle (@_) {
    my $id = $tle->get ('id');
    $data{$id} ||= [];
    push @{$data{$id}}, $tle;
    }
map {@{$data{$_}} > 1 ? $class->new (@{$data{$_}}) :
	@{$data{$_}} ? $data{$_}[0] : ()}
    sort keys %data;
}


=item $set->can ($method);

This method checks to see if the object and execute the given method.
If so, it returns a code reference to the subroutine; otherwise it
returns undef.

This override to UNIVERSAL::can is necessary because we want to return
true for member class methods, but we execute them by autoloading, so
they are not in our namespace.

=cut

sub can {
my ($self, $method) = @_;
my $rslt = UNIVERSAL::can ($self, $method);
$rslt = UNIVERSAL::can ($self->{current}, $method)
    if !$rslt && $self->{current};
$rslt;
}


=item $set->clear ();

This method removes all members from the set, allowing it to be
reloaded with a different NORAD ID.

=cut

sub clear {
my $self = shift;
$self->{current} = undef;
@{$self->{members}} = ();
}


=item @tles = $set->members ();

This method returns all members of the set, in ascending order by
epoch.

=cut

sub members {
my $self = shift;
map {$_->[1]} @{$self->{members}};
}


=item $set->select ($time);

This method selects the member object that best represents the given
time, and returns that member. If called without an argument or with an
undefined argument, it simply returns the currently-selected member.

=cut

sub select {
my $self = shift;
if (defined $_[0]) {
    my $time = shift;
    croak <<eod unless @{$self->{members}};
Error - Can not select a member object until you have added members.
eod
    my ($epoch, $current);
    foreach (@{$self->{members}}) {
	($epoch, $current) = @$_
	    unless defined $epoch && $_->[0] > $time;
	}
    $self->{current} = $current;
    }
$self->{current};
}


=item $set->set ($name => $value ...);

This method iterates over the individual name-value pairs. If the name
is an attribute of Astro::Coord::ECI::TLE, it calls set_selected($name,
$value). Otherwise, it calls set_all($name, $value).

=cut

sub set {
my $self = shift;
while (@_) {
    my $name = shift;
    if ($self->attribute ($name) eq 'Astro::Coord::ECI::TLE') {
	$self->set_selected ($name, shift);
	}
      else {
	$self->set_all ($name, shift);
	}
    }
}


=item $set->set_all ($name => $value ...);

This method sets the given attribute values on all members of the set.
It is not an error to call this on an object with no members, but
neither does it accomplish anything useful.

=cut

sub set_all {
my $self = shift;
foreach my $member (@{$self->{members}}) {
    $member->[1]->set (@_);
    }
}

=item $set->set_selected ($name => $value ...);

This method sets the given attribute values on the currently-selected
member of the set. It is an error to call this on an object with no
members.

=cut

sub set_selected {
my $self = shift;
my $delegate = $_[0]{current} or
    croak sprintf ERR_NOCURRENT, 'set_selected';
$delegate->set (@_);
}


=item $set->universal ($time);

This method selects the member object that best represents the given
time, and calls the universal() method on that object. The $set object
is returned.

=cut

sub universal {
my $self = shift;
croak <<eod unless ref $self;
Error - You may not call universal() as a static method.
eod
if (@_) {
    my $time = shift;
    $self->select ($time)->universal ($time);
    $self;
    }
  else {
    croak sprintf ERR_NOCURRENT, 'universal' unless $self->{current};
    $self->{current}->universal ();
    }
}

#	The AUTOLOAD routine does not define methods, it simply
#	simulates them. This is because there is no good way to
#	get rid of the routines if we end up representing a
#	different class.

sub AUTOLOAD {
our $AUTOLOAD;
(my $routine = $AUTOLOAD) =~ s/.*:://;
my $delegate = $_[0]{current} or
    croak sprintf ERR_NOCURRENT, $routine;
my $coderef;
if ($coderef = $delegate->can ("_nodelegate_$routine")) {
    }
  elsif ($coderef = $delegate->can ($routine)) {
    splice @_, 0, 1, $delegate;	# Not $_[0] = $delegate!!!
    }
  else {
    croak <<eod;
Error - Can not call $routine because it is not supported by
        class @{[ref $delegate]}
eod
    }
$coderef->(@_);
}

sub DESTROY {
my $self = shift;
$self = undef;
}

1;

