use ExtUtils::MakeMaker;

my %deps = (
                  'Rex' => '0.30',
                  'LWP::Simple' => 0,
                  'YAML' => 0,
);

WriteMakefile(
   NAME => 'Rex::IO::BMD',
   VERSION_FROM => 'lib/Rex/IO/BMD.pm',
   PREREQ_PM => \%deps,
   EXE_FILES => ['bin/rex_io_bmd'],
   LICENSE => 'ASL 2.0'
);

