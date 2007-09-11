use strict;
use Module::Build;

Module::Build->new(
   module_name => 'Lingua::Any::Numbers',
   license     => 'perl',
   requires    => {
      'Lingua::EN::Numbers' => 0,
      'Test::More'          => 0,
   },
   recommends  => {
      'Lingua::AF::Numbers' => 0,
      'Lingua::EU::Numbers' => 0,
      'Lingua::FR::Numbers' => 0,
      'Lingua::HU::Numbers' => 0,
      'Lingua::IT::Numbers' => 0,
      'Lingua::JA::Numbers' => 0,
      'Lingua::NL::Numbers' => 0,
      'Lingua::PL::Numbers' => 0,
      'Lingua::TR::Numbers' => 0,
      'Lingua::ZH::Numbers' => 0,
   },
   sign        => 0,
   dist_author => 'Burak Gursoy <burak@cpan.org>',
)->create_build_script;
