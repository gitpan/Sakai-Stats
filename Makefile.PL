use 5.008001;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Sakai::Stats',
    VERSION_FROM => 'lib/Sakai/Stats.pm',    # finds $VERSION
    PREREQ_PM    => {
        Data::Dumper => 2.121_14,
        DBD::mysql   => 3.0002_5,
        DBI          => 1.616,
        Getopt::Long => 2.24,
        Net::LDAP    => 0.34,
        Pod::Usage   => 1.36,
        Text::CSV    => 1.06
    },
    (
        $] >= 5.005
        ?    ## Add these new keywords supported since 5.005
          (
            ABSTRACT_FROM =>
              'lib/Sakai/Stats.pm',    # retrieve abstract from module
            AUTHOR => 'D. D. Parry <perl@ddp.me.uk>'
          )
        : ()
    ),
);
