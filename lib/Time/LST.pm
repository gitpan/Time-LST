package Time::LST;

use 5.008008;
use strict;
use warnings;
use Astro::Time;
use Carp qw(croak);

use vars qw($VERSION @EXPORT_OK);
$VERSION = 0.01;
use Exporter qw( import );
@EXPORT_OK = qw(filestat_2_lst time_2_lst ymdhms_2_lst);

sub filestat_2_lst {
   my ($op, $path, $long) = @_;

   croak __PACKAGE__, '::filestat_2_lst: First argument needs to be create or mod' if $op !~ /^c|m/i;
   croak __PACKAGE__, '::filestat_2_lst: Invalid path to file' if !$path or !-e $path;

   return time_2_lst( (stat($path))[ $op =~ /^c/i ? 10 : 9 ] , $long);

}

sub time_2_lst {
   my ($time, $long) = @_;

   croak __PACKAGE__, '::time_2_lst: Need longitude and time to calculate LST' if !$long || !$time;
    
   my @localtime_ari = localtime($time);

   #$sec,$min,$hour,$mday,$mon,$year    
   return _convert(
        [
           ($localtime_ari[5] += 1900), # year (ISO format)
           ($localtime_ari[4] += 1),   # month
           $localtime_ari[3],         # day of month
           @localtime_ari[2, 1, 0]   # hours, minutes, seconds
        ],
        $long
   );
}

sub ymdhms_2_lst {
   my ($ymdhms, $long) = @_;
    
   croak __PACKAGE__, '::ymdhms_2_lst: Need an array reference and longitude to calculate LST' if !ref $ymdhms || !$long;

   return _convert($ymdhms, $long);
}

sub _convert {
   my ($ymdhms, $long) = @_;

   # Convert hours, minutes & seconds into day fraction, via Astro-Time:
   my $ut_dayfraction = hms2time($ymdhms->[3], $ymdhms->[4], $ymdhms->[5]);

   # Convert angle from string (in Degrees, not Hours) into fraction of a turn, via Astro-Time:
   my $long_turn = str2turn($long, 'D');

   # Convert calendar date into local sidereal time (in turns), via Astro-Time:
   # Usage:  cal2lst($day, $month, $year, $ut, $longitude(in turns));
   my $lst = cal2lst($ymdhms->[2], $ymdhms->[1], $ymdhms->[0], $ut_dayfraction, $long_turn);

   # Convert fraction of a turn into 'H(ours), not D(egrees)', & return it, via Astro-Time:
   # Usage: turn2str($turn, 'H|D', 'No. sig. digits');
   return turn2str($lst, 'H', 0);
}

1;
__END__

=head1 NAME

Time::LST - Convert datetime representations to local sidereal time via Astro-Time

=head1 VERSION

This is documentation for Version 0.01 of Time::LST (2006.11.22).

=head1 SYNOPSIS

  use Time::LST qw(filestat_2_lst time_2_lst ymdhms_2_lst);
  
  $path = 'valid_path_to_a_file';
  $long = -3.21145; # London, in degrees
  
  $lst = filestat_2_lst('mod', $path, $long); # or filestat_2_lst('create', $path, $long)
  $lst = time_2_lst(time(), $long);
  $lst = ymdhms_2_lst([2006, 11, 21, 12, 15, 0], $long);

  print $lst;

=head1 DESCRIPTION

A wrapper to a number of Astro::Time methods that simplifies conversion of a datetime array (such as returned by L<Date::Calc|lib::Date::Calc>), or time in seconds since the epoch (as returned by L<time|perlfunc/time>, or L<stat|perlfunc/stat> fields), into local sidereal time (in hours, minutes and seconds). Give a filepath to get the LST of its last modified time, or see what the LST is now. Essentially, you need to know the longitude (in degrees) of the space relevant to your time.

=head1 METHODS

Methods need to be explicitly imported in the C<use> statement. None are exported by default.

All methods expect a longitude in degrees, e.g. -3.21145 (London), 147.333 (Hobart, Tasmania).

LST is always returned in the format B<H:M:S>, hours ranging from 0 (12 AM) to 23 (11 PM).

=head2 filestat_2_lst

 $lst = filestat_2_lst('create|mod', $path, $long)

Returns LST corresponding to the creation or modification time of a given path. 

First argument equals either 'c' or 'm' (only the first letter is looked-up, case-insensitively). This, respectively, determines access to C<ctime> (element 10) and C<mtime> (element 9) returned by Perl's internal L<stat|perlfunc/stat> function. Note that only modification-time is truly portable across systems; see L<Files and Filesystems in perlport|perlport/Files and Filesystems> (paras 6 and 7). 

The path must be to a "real" file, not a link to a file.

=head2 time_2_lst

 $lst = time_2_lst('1164074032', $long)

Returns LST given seconds since the epoch. If you have a time in localtime format, see L<Time::localtime|Time::localtime> to convert it into the format that can be used with this function.

=head2 ymdhms_2_lst

 $lst = ymdhms_2_lst([2006, 8, 21, 12, 3, 0], $long)

Returns LST corresponding to a datetime given as an array reference of the following elements:

=for html <p>&nbsp;&nbsp;[year (2 or 4-digit), month-of-year (i.e., <i>n</i>th month, not element number returned by localtime()), day-of-month, hour (0 - 23), minutes, seconds]</p>

Range-checking of these values is performed by Astro::Time itself.

=head1 EXAMPLE

=head2 Here and Now

Use Date::Calc and HeavensAbove to get the present LST.

 use Time::LST qw(ymdhms_2_lst);
 use Date::Calc qw(Today_and_Now);
 use WWW::Gazetteer::HeavensAbove;

 my $atlas = WWW::Gazetteer::HeavensAbove->new;
 my $cities = $atlas->find('Hobart', 'AU'); # cityname, ISO country code
 # Assume all went well, and the first city returned is "here".

 print 'The LST here and now is ' . ymdhms_2_lst([Today_and_Now()], $cities->[0]->{'longitude'});

=head1 SEE ALSO

L<Astro::Time|lib::Astro::Time> : the present module uses the C<hms2time>, C<str2turn>, C<turn2str> and C<cal2lst> methods to eventually get the LST for a given time.

L<WWW::Gazetteer::HeavensAbove|lib::WWW::Gazetteer::HeavensAbove> : see this module for determining longitudes of a certain city, or visit L<http://www.heavens-above.com/countries.asp>.

=head1 AUTHOR

Roderick Garton, E<lt>rgarton@utas_DOT_edu_DOT_auE<gt>

=head1 COPYRIGHT/LICENSE/DISCLAIMER

Copyright (C) 2006 Roderick Garton 

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself, either Perl version 5.8.8 or, at your option, any later version of Perl 5 you may have available. 

To the maximum extent permitted by applicable law, the author of this module disclaims all warranties, either express or implied, including but not limited to implied warranties of merchantability and fitness for a particular purpose, with regard to the software and the accompanying documentation.

=cut
