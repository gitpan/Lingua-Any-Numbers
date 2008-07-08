package Lingua::Any::Numbers;
use strict;
use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );

$VERSION = '0.23';

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
use Carp qw(croak);

BEGIN {
   *num2str         = *number_to_string    = \&to_string;
   *num2ord         = *number_to_ordinal   = \&to_ordinal;
   *available_langs = *available_languages = \&available;
}

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
my $DEFAULT    = 'EN';
my $USE_LOCALE = 0;

_probe(); # fetch/examine/compile all available modules

sub import {
   my $class = shift;
   my @args  = @_;
   my @exports;

   foreach my $thing ( @args ) {
      if ( lc $thing eq '+locale' ) { $USE_LOCALE = 1; next; }
      if ( lc $thing eq '-locale' ) { $USE_LOCALE = 0; next; }
      push @exports, $thing;
   }

   $class->export_to_level( 1, $class, @exports );
}

sub to_string  { _to( string  => @_ ) }
sub to_ordinal { _to( ordinal => @_ ) }
sub available  { keys %LMAP           }

# -- PRIVATE -- #

sub _to {
   my $type   = shift || croak "No type specified";
   my $n      = shift;
   my $lang   = shift || _get_lang();
      $lang   = uc $lang;
      $lang   = _get_lang($lang) if $lang eq 'LOCALE';
   if ( ($lang eq 'LOCALE' || $USE_LOCALE) && ! exists $LMAP{ $lang } ) {
      _w("Locale language ($lang) is not available. "
          ."Falling back to default language ($DEFAULT)");
      $lang = $DEFAULT; # prevent die()ing from an absent driver
   }
   my $struct = $LMAP{ $lang };
   croak "Language ($lang) is not available" if ! $struct;
   return $struct->{ $type }->( $n );
}

sub _get_lang {
   my $lang;
   my $locale = shift;
   $lang = _get_lang_from_locale() if $locale || $USE_LOCALE;
   $lang = $DEFAULT if ! $lang;
   return uc $lang;
}

sub _get_lang_from_locale {
   require I18N::LangTags::Detect;
   my @user_wants = I18N::LangTags::Detect::detect();
   my $lang = $user_wants[0] || return;
   ($lang,undef) = split /\-/, $lang; # tr-tr
   return $lang;
}

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

=head1 IMPORT PRAGMAS

Some parameters enable/disable module features. C<+> is prefixed to enable
these options. Pragmas have global effect (i.e.: not lexical), they can not
be disabled afterwards.

=head2 locale

Use the language from system locale:

   use Lingua::Any::Numbers qw(:std +locale);
   print to_string(81); # will use locale

However, the second parameter to the functions take precedence. If the language
parameter is used, C<locale> pragma will be discarded.

Install all the C<Lingua::*::Numbers> modules to take advantage of the
locale pragma.

It is also possible to enable C<locale> usage through the functions.
See L</FUNCTIONS>.

C<locale> is implemented with L<I18N::LangTags::Detect>.

=head1 FUNCTIONS

All language parameters (C<LANG>) have a default value: C<EN>. If it is set to
C<LOCALE>, then the language from the system C<locale> will be used
(if available).

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

=head1 SUPPORT

=head2 BUG REPORTS

All bug reports and wishlist items B<must> be reported via
the CPAN RT system. It is accessible at
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Lingua-Any-Numbers>.

=head2 DISCUSSION FORUM

C<CPAN::Forum> is a place for discussing C<CPAN>
modules. It also has a C<Lingua::Any::Numbers> section at
L<http://www.cpanforum.com/dist/Lingua-Any-Numbers>.

=head2 RATINGS

If you like or hate or have some suggestions about
C<Lingua::Any::Numbers>, you can comment/rate the distribution via 
the C<CPAN Ratings> system: 
L<http://cpanratings.perl.org/dist/Lingua-Any-Numbers>.

=head1 AUTHOR

Burak Gürsoy, E<lt>burakE<64>cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2007-2008 Burak Gürsoy. All rights reserved.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify 
it under the same terms as Perl itself, either Perl version 5.10 or, 
at your option, any later version of Perl 5 you may have available.

=cut
