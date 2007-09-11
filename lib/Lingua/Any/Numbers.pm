package Lingua::Any::Numbers;
use strict;

use subs qw(
   to_string
   num2str
   number_to_string

   to_ordinal
   num2ord
   number_to_ordinal

   available
   available_langs
   available_languages
);

use vars qw(
   $VERSION
   @ISA
   @EXPORT
   @EXPORT_OK
   %EXPORT_TAGS
);

use constant LCLASS          => 0;
use constant LFILE           => 1;
use constant LID             => 2;

use constant PREHISTORIC     =>  $] < 5.006;
use constant LEGACY          => ($] < 5.008) && ! PREHISTORIC;

use constant RE_LEGACY_PERL => qr{
                                 Perl \s+ (.+?) \s+ required
                                 --this \s+ is \s+ only \s+ (.+?),
                                 \s+ stopped
                                 }xmsi;
use constant RE_LEGACY_VSTR => qr{
                                 syntax \s+ error \s+ at \s+ (.+?)
                                 \s+ line \s+ (?:.+?),
                                 \s+ near \s+ "use \s+ (.+?)"
                                 }xmsi;
use constant RE_UTF8_FILE => qr{
                                 Unrecognized \s+ character \s+ \\ \d+ \s+
                                 }xmsi;
use File::Spec;
use Exporter ();

BEGIN {
   *num2str         = *number_to_string    = \&to_string;
   *num2ord         = *number_to_ordinal   = \&to_ordinal;
   *available_langs = *available_languages = \&available;
}

$VERSION = '0.20';

@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(
                  to_string  number_to_string  num2str
                  to_ordinal number_to_ordinal num2ord
                  available  available_langs   available_languages
               );
%EXPORT_TAGS = (
                  all       => [ @EXPORT_OK ],
                  standard  => [ qw/ available           to_string        to_ordinal        / ],
                  standard2 => [ qw/ available_languages to_string        to_ordinal        / ],
                  long      => [ qw/ available_languages number_to_string number_to_ordinal / ],
               );
@EXPORT_TAGS{ qw/ std std2 / } = @EXPORT_TAGS{ qw/ standard standard2 / };

my %LMAP;
my $DEFAULT = 'EN';

_probe(); # fetch/examine/compile all available modules

sub to_string {
   my $n      = shift;
   my $lang   = shift || $DEFAULT;
      $lang   = uc $lang;
   my $struct = $LMAP{ $lang };
   die "Language ($lang) is not available" if ! $struct;
   return $struct->{string}->( $n );
}

sub to_ordinal {
   my $n      = shift;
   my $lang   = shift || $DEFAULT;
      $lang   = uc $lang;
   my $struct = $LMAP{ $lang };
   die "Language ($lang) is not available" if ! $struct;
   return $struct->{ordinal}->( $n );
}

sub available { keys %LMAP }

# -- PRIVATE -- #

sub _is_silent () { defined &SILENT && &SILENT }

sub _dummy_ordinal { $_[0] }
sub _dummy_string  { $_[0] }
sub _dummy_oo      {
   my $class = shift;
   sub { $class->new->parse( shift ) }
}

sub _probe {

   local *DIRH;
   my($path, $dir, $file);
   my @classes;
   foreach my $inc ( @INC ) {
      $path = File::Spec->catfile( $inc, 'Lingua' );
      next if ! -d $path;
      opendir  DIRH, $path or die "opendir($path): $!";
      while ( $dir = readdir DIRH ) {
         next if $dir =~ m{ \A \. }xms;
         next if $dir eq 'Any';
         $file = File::Spec->catfile( $path, $dir, 'Numbers.pm' );
         next if ! -e $file;
         next if   -d _;
         push @classes, [
            join('::', 'Lingua', $dir, 'Numbers'),
            $file,
            $dir,
         ];
      }
      closedir DIRH;
   }

   my($code, @compile, $class);
   foreach my $module ( @classes ) {
      $class = $module->[LCLASS];

      # PL driver is problematic under 5.5.4
      if ( PREHISTORIC && $class->isa('Lingua::PL::Numbers') ) {
         _w("Disabling $class under legacy perl ($])") && next;
      }

      $code  = "require $class; $class->import;";
      eval $code;
      # some modules need attention
      if ( my $e = $@ ) {
         _w(_eprobe( $class, $1, $2 )) && next if $e =~ RE_LEGACY_PERL; # JA -> 5.6.2
         _w(_eprobe( $class, $2, $] )) && next if $e =~ RE_LEGACY_VSTR; # HU -> 5.005_04
         _w(_eprobe( $class, $]     )) && next if $e =~ RE_UTF8_FILE;   # JA -> 5.005_04
         die "An error occurred while including sub modules: $e";
      }
      else {
         push @compile, $module;
      }
   }
   _compile( \@compile );

}

sub _w {
   return 1 if _is_silent();
   warn "@_\n";
}

sub _eprobe {
   my $tmp = @_ == 3 ? "%s requires a newer (%s) perl binary. You have %s"
           :           "%s requires a newer perl binary. You have %s"
           ;
   return sprintf $tmp, @_
}

sub _compile {
   my $classes = shift;
   my(%sym, $lcid, $id, $to, $to2, $ord, $cl);
   no strict qw(refs);

   foreach my $e ( @{ $classes } ) {
      $id   = $e->[LID];
      $lcid = lc $id;
      $to   = "num2${lcid}";
      $to2  = "number_to_${lcid}";
      $ord  = "num2${lcid}_ordinal";
      $cl   = $e->[LCLASS];
      %sym  = %{ $cl . "::" };

      $LMAP{ $id } = {}; # init cache

         if ( $sym{ $to  }          ) { $LMAP{ $id }->{ string  } = \&{ $cl . "::" . $to         } }
      elsif ( $sym{ $to2 }          ) { $LMAP{ $id }->{ string  } = \&{ $cl . "::" . $to2        } }
      elsif ( $sym{cardinal2alpha}  ) { $LMAP{ $id }->{ string  } = \&{ $cl . "::cardinal2alpha" } }
      elsif ( $sym{parse}           ) { $LMAP{ $id }->{ string  } =   _dummy_oo( $cl )             }
      else                            { $LMAP{ $id }->{ string  } = \&_dummy_string              }

         if ( $sym{ $ord }          ) { $LMAP{ $id }->{ ordinal } = \&{ $cl . "::" . $ord        } }
      elsif ( $sym{ordinal2alpha}   ) { $LMAP{ $id }->{ ordinal } = \&{ $cl . "::ordinal2alpha"  } }
      else                            { $LMAP{ $id }->{ ordinal } = \&_dummy_ordinal;              }
   }
   undef %sym;
}

1;

__END__

=pod

=head1 NAME

Lingua::Any::Numbers - Converts numbers into (any available language) string.

=head1 SYNOPSIS

   use Lingua::Any::Numbers qw(:std);
   printf "Available languages are: %s\n", join( ", ", available );
   printf "%s\n", to_string(  45 );
   printf "%s\n", to_ordinal( 45 );

or test all available languages

   use Lingua::Any::Numbers qw(:std);
   foreach my $lang ( available ) {
      printf "%s\n", to_string(  45, $lang );
      printf "%s\n", to_ordinal( 45, $lang );
   }

=head1 DESCRIPTION

=head1 IMPORT PARAMETERS

All functions and aliases can be imported individually, 
but there are some pre-defined import tags:

   :all        Import everything (including aliases)
   :standard   available(), to_string(), to_ordinal().
   :std        Alias to :standard
   :standard2  available_languages(), to_string(), to_ordinal()
   :std2       Alias to :standard2
   :long       available_languages(), number_to_string(), number_to_ordinal()

=head1 FUNCTIONS

All language parameters (C<LANG>) have a default value: C<EN>.

=head2 to_string NUMBER [, LANG ]

Aliases:

=over 4

=item num2str

=item number_to_string

=back

=head2 to_ordinal NUMBER [, LANG ]

Aliases: 

=over 4

=item num2ord

=item number_to_ordinal

=back

=head2 available

Returns a list of available language ids.

Aliases:

=over 4

=item available_langs

=item available_languages

=back

=head1 DEBUGGING

=head2 SILENT

If you define a sub named C<Lingua::Any::Numbers::SILENT> and return
a true value from that, then the module will not generate any warnings
when it faces some recoverable errors.

C<Lingua::Any::Numbers::SILENT> is not defined by default.

=head1 CAVEATS

=over 4

=item *

Some modules return C<UTF8>, while others return arbitrary encodings.
C<ascii> is ok, but others will be problematic. A future release can 
convert all to C<UTF8>.

=item *

All available modules will immediately be searched and loaded into
memory (before using any function).

=item *

No language module (except C<Lingua::EN::Numbers>) is required by 
L<Lingua::Any::Numbers>, so you'll need to install the other 
modules manually.

=back

=head1 SEE ALSO

L<Lingua::AF::Numbers>, L<Lingua::EN::Numbers>, L<Lingua::EU::Numbers>,
L<Lingua::FR::Numbers>, L<Lingua::HU::Numbers>, L<Lingua::IT::Numbers>,
L<Lingua::JA::Numbers>, L<Lingua::NL::Numbers>, L<Lingua::PL::Numbers>,
L<Lingua::TR::Numbers>, L<Lingua::ZH::Numbers>.

=head1 AUTHOR

Burak Gürsoy, E<lt>burakE<64>cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2007 Burak Gürsoy. All rights reserved.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify 
it under the same terms as Perl itself, either Perl version 5.8.8 or, 
at your option, any later version of Perl 5 you may have available.

=cut
