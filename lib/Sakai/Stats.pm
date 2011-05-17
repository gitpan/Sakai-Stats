package Sakai::Stats;

use 5.008001;
use strict;
use warnings;
use Carp;
use Sakai::Stats::Database;
use Sakai::Stats::Institutions;

require Exporter;

use base qw(Exporter);

our @EXPORT_OK = ();

our $VERSION = '0.02';

#{{{sub new

sub new {
    my ($class) = @_;
    my $dbhost  = 'localhost';
    my $dbname  = 'sakai';
    my $dbpass  = 'pass';
    my $dbport  = '3306';
    my $dbuser  = 'user';
    my $help;
    my $institution;
    my $ldapbase;
    my $ldaphost;
    my $ldapinstbase;
    my $man;
    my $workdir = '.';
    my @years;

    my $stats = {
        DBHost       => $dbhost,
        DBName       => $dbname,
        DBPass       => $dbpass,
        DBPort       => $dbport,
        DBUser       => $dbuser,
        Help         => $help,
        Institution  => $institution,
        LdapBase     => $ldapbase,
        LdapHost     => $ldaphost,
        LdapInstBase => $ldapinstbase,
        Man          => $man,
        WorkDir      => $workdir,
        Years        => \@years,
    };
    bless $stats, $class;
    return $stats;
}

#}}}

#{{{sub generate_institution_stats

sub generate_institution_stats {
    my ($stats) = @_;

    # Generate map of user to institution id(s):
    my $institutions = new Sakai::Stats::Institutions( \$stats );
    $institutions->generate_user_insts
      || croak 'Problem generating user to institution(s) map.';

    # Generate map of instid to institution name:
    $institutions->generate_names_for_ids
      || croak 'Problem generating institution id to name map.';

    $institutions->inst_membership_count
      || croak 'Problem generating institution membership count map.';

    # Connect to the database containing data:
    my $database = new Sakai::Stats::Database( \$stats );
    $database->make_connection || croak 'Problem connecting to the database.';

    # Clear the unique instid file if already present:
    if ( -e $stats->{'WorkDir'} . '/unique_instids.csv' ) {
        unlink $stats->{'WorkDir'} . '/unique_instids.csv';
    }

    my @months =
      ( '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11',
        '12' );

    foreach my $year ( @{ $stats->{'Years'} } ) {
        foreach my $month (@months) {
            $institutions->unique_for_month( $year, $month, \$database )
              || croak
              'Problem generating unique institutions per month statistics.';
        }
    }
    return 1;
}

#}}}

#{{{sub generate

sub generate {
    my ($stats) = @_;

    # Set up default set of years if none have been specifed:
    if ( !defined @{ $stats->{'Years'} } ) {
        @{ $stats->{'Years'} } =
          ( '2005', '2006', '2007', '2008', '2009', '2010', '2011' );
    }

    if ( $stats->{'Institution'} ) {
        $stats->generate_institution_stats;
    }
    return 1;
}

#}}}

#{{{sub stats_config

sub stats_config {
    my ($stats) = @_;

    my %stats_config = (
        'dbhost'       => \$stats->{'DBHost'},
        'dbname'       => \$stats->{'DBName'},
        'dbpass'       => \$stats->{'DBPass'},
        'dbport'       => \$stats->{'DBPort'},
        'dbuser'       => \$stats->{'DBUser'},
        'help'         => \$stats->{'Help'},
        'institution'  => \$stats->{'Institution'},
        'ldapbase'     => \$stats->{'LdapBase'},
        'ldaphost'     => \$stats->{'LdapHost'},
        'ldapinstbase' => \$stats->{'LdapInstBase'},
        'man'          => \$stats->{'Man'},
        'workdir'      => \$stats->{'WorkDir'},
        'years'        => \@{ $stats->{'Years'} },
    );

    return \%stats_config;
}

#}}}

1;
