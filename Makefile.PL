use ExtUtils::MakeMaker;

my %deps = (
                  'Rex' => '0.23',
                  'LWP::Simple' => 0,
                  'YAML' => 0,
);

WriteMakefile(
   NAME => 'Rex::IO',
   VERSION_FROM => 'lib/Rex/IO.pm',
   PREREQ_PM => \%deps,
   EXE_FILES => ['bin/rex.io'],
   LICENSE => 'GPL'
);

