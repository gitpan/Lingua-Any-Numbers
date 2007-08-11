use ExtUtils::MakeMaker;

WriteMakefile(
   'NAME'         => 'Lingua::Any::Numbers',
   'VERSION_FROM' => 'lib/Lingua/Any/Numbers.pm',
   'PREREQ_PM'    => {
      'Lingua::En::Numbers' => 0,
      'Test::More'          => 0,
   },
   ($] >= 5.005 ? (
   AUTHOR   => 'Burak Gursoy <burak@cpan.org>',
   ABSTRACT => 'Converts numbers into any available language',
   ) : ()),
   PL_FILES => {},
);

print <<RECOMMENDED;
Recommended Modules:

      Lingua::AF::Numbers
      Lingua::EU::Numbers
      Lingua::FR::Numbers
      Lingua::HU::Numbers
      Lingua::IT::Numbers
      Lingua::JA::Numbers
      Lingua::NL::Numbers
      Lingua::PL::Numbers
      Lingua::TR::Numbers
      Lingua::ZH::Numbers

RECOMMENDED
