package Time::LST;

use 5.008008;
use strict;
use warnings;
use Astro::Time;
use Carp qw(croak);
use vars qw($VERSION @EXPORT_OK);
$VERSION = 0.02;
use Exporter qw(import);
@EXPORT_OK = qw(datetime_2_lst filestat_2_lst now_2_lst time_2_lst ymdhms_2_lst);

sub datetime_2_lst {
   my ($str, $long, $tz) = @_;
   croak __PACKAGE__, '::datetime_2_lst: Need a datetime string' if !$str;
   require Date::Parse;
   my @ari = Date::Parse::strptime($str);
   croak __PACKAGE__, '::datetime_2_lst: Check datetime: the sent datetime did not parse' if ! scalar @ari;
   pop @ari;
   $ari[4] += 1;
   $ari[5] += 1900 if $ari[5] < 1000;
   return ymdhms_2_lst([reverse @ari], $long, $tz);
}

sub filestat_2_lst {
   my ($op, $path, $long) = @_;
   croak __PACKAGE__, '::filestat_2_lst: First argument needs to be create or mod' if $op !~ /^c|m/i;
   croak __PACKAGE__, '::filestat_2_lst: Invalid path to file' if !$path or !-e $path;
   return time_2_lst( (stat($path))[ $op =~ /^c/i ? 10 : 9 ] , $long);
}

sub now_2_lst {
    return time_2_lst(time(), $_[0]);
}

sub ymdhms_2_lst {
   my ($ymdhms, $long, $tz) = @_;
   croak __PACKAGE__, '::ymdhms_2_lst: Need an array reference to calculate LST' if ! ref $ymdhms;
   croak __PACKAGE__, '::ymdhms_2_lst: Need an array reference of datetime (6 values) to calculate LST' if ! ref $ymdhms eq 'ARRAY' or scalar @{$ymdhms} != 6;
   #my $ut = hms2time($ymdhms->[3], $ymdhms->[4], $ymdhms->[5]);
   #my $mjd = cal2mjd($ymdhms->[2], $ymdhms->[1], $ymdhms->[0], $ut);
   #my $lst = mjd2lst($mjd, $long);
   #return turn2str($lst, 'H', 0);
   $ymdhms->[0] = 1970 if $ymdhms->[0] < 1970;
   $ymdhms->[0] = 2037 if $ymdhms->[0] > 2037;
   my $epoch;
   $tz ||= 'local'; # Date::Parse appears to handle local more efficiently than DateTime as a default
   if ($tz =~ /^([A-Z]{3,5}|local)$/) { # e.g., 'AEDT', 'BST'
       require Date::Parse;
	   my $str = join':', (@{$ymdhms}[0 .. 5]);
       $epoch = Date::Parse::str2time($str, $tz);
   }
   else {
       require DateTime;
	   my @dkeys = (qw/year month day hour minute second/);
	   my $i = 0;
       my $dt = DateTime->new( 
	   			 ( map { $dkeys[$i++] => $_ } @{$ymdhms} ),
                 #year   => $ymdhms->[0],
                 #month  => $ymdhms->[1],
                 #day    => $ymdhms->[2],
                 #hour   => $ymdhms->[3],
                 #minute => $ymdhms->[4],
                 #second => $ymdhms->[5],
                 time_zone => $tz,
       );
       $epoch = $dt->epoch();
     
   }
   croak __PACKAGE__, '::ymdhms_2_lst: Check datetime: the sent datetime did not parse' if !$epoch;
   return time_2_lst($epoch, $long);
}

sub time_2_lst {
   my ($time, $long) = @_;
   croak __PACKAGE__, '::time_2_lst: Need longitude and time to calculate LST' if !$long || !$time;
   my @time_ari = gmtime($time);
   return _convert(
        [
           ($time_ari[5] + 1900), # year (ISO format)
           ($time_ari[4] + 1),   # month
           $time_ari[3],         # day of month
           @time_ari[2, 1, 0]   # hours, minutes, seconds
        ],
        $long
   );
}

sub _convert {
   my ($ymdhms, $long) = @_;

   # Convert hours, minutes & seconds into day fraction, via Astro-Time:
   #my $ut_dayfraction = hms2time(_adjust_hr($ymdhms->[3], $dst), $ymdhms->[4], $ymdhms->[5]);
   my $ut_dayfraction = hms2time($ymdhms->[3], $ymdhms->[4], $ymdhms->[5]);

   # Convert angle from string (in Degrees, not Hours) into fraction of a turn, via Astro-Time:
   my $long_turn = str2turn($long, 'D');

   # Convert calendar date & time (dayfraction) into Julian Day, via Astro-Time:
   # Usage:  cal2mjd($day, $month, $year, $ut);
   my $mjd = cal2mjd($ymdhms->[2], $ymdhms->[1], $ymdhms->[0], $ut_dayfraction);

   # Convert Julian day into fraction of a turn, and this
   # into 'H(ours)' (not D(egrees)), & return it, via Astro-Time:
   # Usage: 
   #  $lst = mjd2lst($mjd, $longitude_in_turns) - e.g. (54077.4666550926, 0.409258333333333)
   #  turn2str($lst, 'H|D', 'No. sig. digits');
   return turn2str(mjd2lst($mjd, $long_turn), 'H', 0);
}

1;
__END__

=head1 NAME

Time::LST - Convert datetime representations to local sidereal time via Astro-Time

=head1 VERSION

This is documentation for Version 0.02 of Time::LST (2006.12.08).

=head1 SYNOPSIS

  use Time::LST qw(filestat_2_lst now_2_lst time_2_lst ymdhms_2_lst);
  
  $path = 'valid_path_to_a_file';
  $long = -3.21145; # London, in degrees
  
  $lst = filestat_2_lst('mod', $path, $long); # or filestat_2_lst('create', $path, $long)
  $lst = time_2_lst(time(), $long); # "now" in LST
  $lst = ymdhms_2_lst([2006, 11, 21, 12, 15, 0], $long, 'eadt'); # optional timezone

  print $lst;

=head1 DESCRIPTION

A wrapper to a number of Astro::Time methods that simplifies conversion of a datetime array (such as returned by L<Date::Calc|lib::Date::Calc>), or time in seconds since the epoch (as returned by L<time|perlfunc/time>, or L<stat|perlfunc/stat> fields), into local sidereal time (in hours, minutes and seconds). 

Give a filepath to get the LST of its last modified time, or readily see what the LST is now. 

Essentially, you need to know the longitude (in degrees) of the space relevant to your time.

Optionally, a timezone string in some methods can be helpful for accurately parsing (solar) clock-and-calendar times.

My original intention was to be able to get LST for clock-times occurring in the UK during World War 2, when double daylight saving time (+2 hours from GMT) was occasionally in force. This was outside of normal timezone-conversion solutions. This is now simply possible via the ymdhms_2_lst() method.

=head1 METHODS

Methods need to be explicitly imported in the C<use> statement. None are exported by default.

All methods expect a longitude, either in I<degrees.decimal> or I<degrees:minutes:seconds> - e.g. -3.21145 (London), 147.333 (Hobart, Tasmania) - or degrees+minutes - e.g., 147:19:58.8 (Hobart). See the L<str2turn|lib::Astro::Time/str2turn> method in the Astro::Time module for valid representations of longitude. Note, however, the degrees, not hours, are here supported.

LST is always returned in the format B<H:M:S>, hours ranging from 0 (12 AM) to 23 (11 PM).

=head2 datetime_2_lst

 $lst = datetime_2_lst('1942:12:27:16:04:07', -3.21145, 'BST')

Returns LST on the basis of parsing a datetime string into "seconds since the epoch". This string can be in any form parseable by L<Date::Parse|lib::Date::Parse>. Note that there are system limitations in handling years outside of a certain range. Years less than 1000 will not parse. Years between 1000 and 1969, inclusive, will be rendered as 1970, and those greater than 2037 will be rendered as 2037. (LST annually deviates by only about 3 minutes from 1970 to 2037).

Longitude in degrees is mandatory. 

A timezone string can be specified as an optional third argument for accurate parsing of the datetime string into "seconds since the epoch"; the local timezone is used if this is not specified. Valid representations include the likes of "AEDT" and "EST" (parsed by Date::Parse; i.e., a capital-letter string of 3-5 letters in length), or "Australia/Hobart" (parsed by DateTime).

=head2 filestat_2_lst

 $lst = filestat_2_lst('create|mod', $path, $long)

Returns LST corresponding to the creation or modification time of a given path. 

First argument equals either 'c' or 'm' (only the first letter is looked-up, case-insensitively). This, respectively, determines access to C<ctime> (element 10) and C<mtime> (element 9) returned by Perl's internal L<stat|perlfunc/stat> function. Note that only modification-time is truly portable across systems; see L<Files and Filesystems in perlport|perlport/Files and Filesystems> (paras 6 and 7). 

The path must be to a "real" file, not a link to a file.

=head2 now_2_lst

 $lst = now_2_lst($long)

Returns local now (as returned by perl's time()) as LST, given longitude in degrees.

Same as going: C<time_2_lst(time(), $long)>.

=head2 time_2_lst

 $lst = time_2_lst('1164074032', $long)

Returns LST given seconds since the epoch. If you have a time in localtime format, see L<Time::localtime|Time::localtime> to convert it into the format that can be used with this function.

=head2 ymdhms_2_lst

 $lst = ymdhms_2_lst([2006, 8, 21, 12, 3, 0], $long, $timezone)

Returns LST corresponding to a datetime given as an array reference of the following elements:

=for html <p>&nbsp;&nbsp;[<br>&nbsp;&nbsp;&nbsp;year (4-digit <i>only</i>),<br>&nbsp;&nbsp;&nbsp;month-of-year (i.e., <i>n</i>th month (ranging 1-12), not month index as returned by localtime()),<br>&nbsp;&nbsp;&nbsp;day-of-month (1-31, no pseudo-octals such as "08"),<br>&nbsp;&nbsp;&nbsp;hour (0 - 23),<br>&nbsp;&nbsp;&nbsp;minutes,<br>&nbsp;&nbsp;&nbsp;seconds<br>&nbsp;&nbsp;]</p>

Range-checking of these values is performed by Astro::Time itself. Ensure that the year is 4-digit representation, and do not send the likes of "08" for 8.

A value for longitude is required secondary to this datetime array.

A final timezone string - e.g., 'EST', 'AEDT' - is optional. Sending nothing, or an erroneous timezone string, assumes present local timezone. The format is as used by L<Date::Parse|Date::Parse> or L<DateTime|DateTime>; UTC+I<n> format does not parse.

=head1 EXAMPLE

=head2 Here and Now

Use HeavensAbove and Date::Calc to blindly get the present LST.

 use Time::LST qw(ymdhms_2_lst);
 use Date::Calc qw(Today_and_Now);
 use WWW::Gazetteer::HeavensAbove;

 my $atlas = WWW::Gazetteer::HeavensAbove->new;
 my $cities = $atlas->find('Hobart', 'AU'); # cityname, ISO country code
 # Assume call went well, and the first city returned is "here".

 print 'The LST here and now is ' . ymdhms_2_lst([Today_and_Now()], $cities->[0]->{'longitude'});

=head1 SEE ALSO

L<Astro::Time|lib::Astro::Time> : the present module uses the C<turn2str>, C<hms2time>, C<str2turn>, C<cal2mjd>, and C<mjd2lst> methods to eventually get the LST for a given time.

L<Date::Parse|lib::Date::Parse> : the present module uses the C<str2time> method to parse datetime strings to a format that can be readily converted to LST via C<ymdhms_2_time()>. See this module for parsing other datetime representations into a "time" format that can be sent to C<time_2_lst()>.

L<WWW::Gazetteer::HeavensAbove|lib::WWW::Gazetteer::HeavensAbove> : see this module for determining longitudes of a certain city, or visit L<http://www.heavens-above.com/countries.asp>.

L<http://home.tiscali.nl/~t876506/TZworld.html> for valid timezone strings.

=head1 AUTHOR

Roderick Garton, E<lt>rgarton@utas_DOT_edu_DOT_auE<gt>

=head1 ACKNOWLEDGEMENT

The author of Astro::Time kindly looked over the basic conversion wrap-up. Any errors remain those of the present author.

=head1 COPYRIGHT/LICENSE/DISCLAIMER

Copyright (C) 2006 Roderick Garton 

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself, either Perl version 5.8.8 or, at your option, any later version of Perl 5 you may have available. 

To the maximum extent permitted by applicable law, the author of this module disclaims all warranties, either express or implied, including but not limited to implied warranties of merchantability and fitness for a particular purpose, with regard to the software and the accompanying documentation.

=cut
